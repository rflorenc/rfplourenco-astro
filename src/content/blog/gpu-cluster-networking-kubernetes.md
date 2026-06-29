---
title: "GPU Cluster Networking on Kubernetes"
description: "An architectural deep-dive into how containers get direct GPU-to-network and GPU-to-storage access on Kubernetes with SR-IOV, Multus CNI, GPUDirect, and the full NVIDIA communication stack."
date: 2026-06-28
tags: ["ai", "kubernetes", "security"]
featured: true
---

In 1984, [John Gage coined "the network is the computer"](https://en.wikipedia.org/wiki/The_Network_is_the_Computer) as a slogan for Sun Microsystems. Four decades later, GPU clusters prove him right in the most literal sense. A single [NVIDIA H100 SXM delivers 3,958 TFLOPS of FP8 Tensor Core throughput](https://resources.nvidia.com/en-us-gpu-resources/h100-datasheet-24306) with [2:4 structured sparsity](https://developer.nvidia.com/blog/accelerating-inference-with-sparsity-using-ampere-and-tensorrt/), where exactly 2 out of every 4 weight elements are zero, letting the hardware skip half the multiply-accumulate operations. Even at the dense (non-sparse) rate of 1,979 TFLOPS, raw compute is generally not the limiting factor. What determines whether GPUs spend their cycles on matrix operations or stalling is the communication fabric: how fast gradients synchronize across devices, how quickly KV-cache is updated in inference stages, and how efficiently model weights load from storage.

This post walks through an example communication stack for GPU workloads on Kubernetes, with focus on how container networking gives pods direct, kernel-bypass access to GPU-attached network hardware.

## The Communication Stack

The GPU communication stack has five layers.

At the bottom, [OFED (OpenFabrics Enterprise Distribution)](https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/) provides the kernel modules and userspace libraries such as libibverbs and librdmacm that expose RDMA capabilities. NVIDIA ships MLNX_OFED as their certified distribution with added firmware and diagnostics for ConnectX NICs. On clusters with BlueField DPUs, [DOCA](https://developer.nvidia.com/networking/doca) replaces OFED, letting the SmartNIC itself run an OS and offload networking, security, and storage.

Above the drivers we have the network adapters. [NVIDIA ConnectX-7 NICs](https://www.nvidia.com/content/dam/en-zz/Solutions/networking/infiniband/connectx-7-datasheet.pdf) support 400 Gb/s per port over InfiniBand or Ethernet, with hardware support for RDMA, GPUDirect, and SR-IOV, presenting a single physical NIC as multiple virtual functions for per-container direct access.

The transport layer is what moves data between nodes. [InfiniBand NDR](https://www.nvidia.com/en-us/networking/products/infiniband/) provides ~400 Gb/s per port with the lowest latency available. [RoCE (RDMA over Converged Ethernet)](https://docs.nvidia.com/networking/display/rdmacore60/RoCE+Configuration) runs RDMA on standard Ethernet using UDP/IP, making it routable across L3 networks. Both bypass the CPU and OS kernel: the NIC reads from and writes to remote memory directly.

Nvidia's [NCCL](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/overview.html) communication libraries sit on top, handling multi-GPU collective operations (all-reduce, broadcast) and is the default backend for PyTorch distributed training. [UCX](https://openucx.org/) works underneath, automatically selecting the best transport: shared memory intra-node, RDMA inter-node. [NVSHMEM](https://developer.nvidia.com/nvshmem) provides one-sided GPU-to-GPU memory access without CPU involvement. [NIXL](https://developer.nvidia.com/blog/enhancing-distributed-inference-performance-with-the-nvidia-inference-transfer-library/) is built for inference, enabling [disaggregated serving in vLLM](https://docs.vllm.ai/en/stable/features/nixl_connector_usage/) where prefill and decode run on separate GPUs with KV-cache transferred between them.

At the top, frameworks like PyTorch and vLLM use these libraries to implement parallelism strategies across GPUs.

## GPUDirect: Eliminating CPU Copies

Traditional data movement between a GPU and a remote machine involves multiple copies: GPU memory to system RAM, system RAM to NIC buffer, across the network, then the reverse.  

[GPUDirect RDMA (GDR)](https://docs.nvidia.com/cuda/gpudirect-rdma/) removes the CPU from the network path. A remote NIC reads from or writes to GPU memory directly over RDMA with no staging through system RAM. For multi-node training where GPUs synchronize gradients on every backward pass, this is what keeps communication overhead from becoming the dominant cost.

[GPUDirect Storage (GDS)](https://docs.nvidia.com/gpudirect-storage/overview-guide/index.html) does the same for storage I/O. NVMe drives and NFS mounts DMA directly into GPU memory, bypassing the CPU bounce buffer. This accelerates model loading and checkpointing during long training runs.

Both require ConnectX-5 or later, compatible GPU firmware, and MLNX_OFED kernel modules. They also require that the GPU and NIC share the same PCIe switch to avoid crossing the CPU's root complex.

## Container Networking for GPU Workloads

Standard Kubernetes networking gives each pod a single interface on a flat overlay. GPU workloads that need RDMA access to dedicated high-speed fabric require a multi-network architecture.

![GPU cluster networking architecture showing three network paths per pod: OVS for management, SR-IOV RDMA for GPU-to-GPU communication, and IPVLAN for GPU-to-storage DMA](/images/gpu-cluster-networking.svg)

The management plane uses Open vSwitch (OVS), providing the standard pod network for API traffic, health checks, and control plane communication. 

For GPU communication, pods get additional interfaces through [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni). SR-IOV virtual functions carved from physical ConnectX NICs are passed directly into pods, giving each container a hardware-backed interface with full RDMA capability. VFs are allocated by the SR-IOV device plugin and requested through standard Kubernetes resource declarations (`rdma/rdma_vf`).

[IPVLAN](https://www.kernel.org/doc/html/latest/networking/ipvlan.html) provides a third attachment for storage traffic (GDS), typically backed by ConnectX-6 NICs on a separate VLAN for traffic isolation. IPVLAN interfaces share the host's MAC address while getting their own IP, working well in MACVLAN-restricted switch environments.

Policy enforcement uses [Gatekeeper (OPA)](https://open-policy-agent.github.io/gatekeeper/) to control which namespaces can access SR-IOV resources. Pods in privileged tiers get ConnectX-7 RDMA VFs for GPUDirect; others are restricted to the standard OVS network. This prevents unprivileged workloads from consuming high-speed network resources and enforces tenant isolation.

The result: three distinct network paths per pod. OVS for management, SR-IOV VFs for GPU-to-GPU RDMA, IPVLAN for GPU-to-storage DMA.

## Parallelism Strategies and Network Requirements

How you split a model across GPUs often determines your network requirements.

**Tensor parallelism (TP)** divides individual layers across GPUs. Every GPU holds a slice of every layer and must synchronize on every forward and backward pass. This requires the fastest interconnect available: [NVLink 4.0 at 900 GB/s bidirectional](https://www.nvidia.com/en-us/data-center/nvlink/) within a node, ideally InfiniBand with GDR across nodes. TP typically stays within a single node.

**Pipeline parallelism (PP)** assigns sequential blocks of layers to different GPUs. Communication happens only at stage boundaries, so PP tolerates higher-latency interconnects. The tradeoff is pipeline bubbles where GPUs idle waiting for activations from the previous stage.

**Expert parallelism (EP)** targets Mixture-of-Experts architectures (Mixtral, DeepSeek). Each GPU hosts different expert sub-networks, and all-to-all communication routes tokens to the relevant expert. Traffic patterns are less predictable and benefit from high-bandwidth all-to-all fabric.

**Data parallelism (DP)** is the simplest form: every GPU holds a full model copy and processes different batches, synchronizing gradients via all-reduce after each step. DP is the most tolerant of network latency since synchronization happens once per training step.

In practice, large-scale training can potentially combine all four: TP within a node over NVLink, PP across nodes over InfiniBand, EP across expert-hosting nodes, DP across remaining replicas.

## Scaling Beyond a Single Node

On a single 8-GPU node, NVLink handles all GPU-to-GPU communication. The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) manages driver installation, device plugins, and NCCL configuration.  

Multi-node changes the picture. [NVSwitch](https://www.nvidia.com/en-us/data-center/nvlink/) now extends across nodes via the NVLink Switch architecture, providing NVLink-speed connectivity between GPUs in different chassis and eliminating the bandwidth cliff at node boundaries.

For infrastructure offloading, [BlueField-3 DPUs](https://www.nvidia.com/content/dam/en-zz/Solutions/Data-Center/documents/datasheet-nvidia-bluefield-3-dpu.pdf) move networking, security, and storage functions onto the SmartNIC's 16 Arm cores and 32 GB of onboard DDR5. The DPU handles SR-IOV management, RDMA configuration, and network policy enforcement without consuming host CPU cycles. In multi-tenant environments, this keeps isolation and resource accounting from impacting GPU workload performance.

The [NVIDIA Network Operator](https://docs.nvidia.com/networking/display/kubernetes2410/nvidia+network+operator) complements the GPU Operator by managing MLNX_OFED drivers, RDMA device plugins, and secondary network configuration. Together they automate the full stack from driver installation through SR-IOV VF allocation to NCCL environment variable tuning.

## Closing Thoughts

In short and after all the technical jargon and "hyperlink soup", the communication stack from OFED drivers through ConnectX NICs, RDMA transport, and NCCL collectives determines whether GPUs compute or wait. Getting container networking right with Multus, SR-IOV, and GPUDirect is a viable infrastructure setup that makes running GPU-accelerated workloads on Kubernetes possible.
