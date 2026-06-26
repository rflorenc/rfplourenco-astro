---
title: "Three Experts, One Model: Making Small Language Models Reliable"
description: "How multi-perspective prompting and self-verification can make small language models produce reliable predictions without scaling to larger, more expensive models."
date: 2026-06-27
tags: ["ai", "python"]
---

When you have a serious medical concern, you do not rely on a single opinion. You see a specialist, maybe two. A cardiologist focuses on your heart. A neurologist focuses on your nervous system. A general practitioner looks at the whole picture. If two out of three agree on a diagnosis, you feel more confident. If all three agree, you are fairly certain.

This is the core idea behind self-consistency in language models. But the technique was originally designed for models with hundreds of billions of parameters, the kind that cost thousands of dollars per hour to run. In our research, we adapted it to work with models small enough to run on a single consumer GPU, and the results surprised us.

## The single-shot problem

NVIDIA Research [defines small language models](https://arxiv.org/abs/2506.02153) as language models capable of operating on consumer-grade hardware with low latency inference, offering the potential to combine the reasoning capabilities of large language models with the practical constraints of real-world deployment. Most applications that use these models today send a prompt, get one answer, and use it. They are fast and cheap to run but prone to confident-sounding mistakes. There is no built-in signal that says "I might be wrong about this one."

The natural instinct is to reach for a bigger model. But bigger models need expensive hardware, more energy, and more time. So the question becomes: can we make a small model more reliable without replacing it with a bigger one?

## Asking the same model three different questions

The original self-consistency technique, proposed by Wang et al. in 2022, works by asking a large model the same question multiple times at a higher temperature. Temperature is a setting that introduces randomness into the model's output. You get several different reasoning paths, then take a majority vote on the final answer.

This does not work well with small models. When you increase the temperature on a 2-billion-parameter model, you do not get creative diversity. You get incoherent noise.

Our approach replaces randomness with structure. Instead of asking the same question three times and hoping for different reasoning, we ask three different questions about the same input. Each question frames the problem from a different expert perspective.

Imagine you are looking at unusual network traffic and you want to know if it is an attack. Instead of asking a general "is this anomalous?" three times, you could ask a network security expert to look for attack signatures and suspicious ports. You could ask a network administrator to assess whether the traffic patterns are operationally normal. You could ask a threat hunter to consider what an attacker might be trying to accomplish.

Each perspective examines different evidence, applies different domain knowledge, and reaches its own conclusion. Then you take the majority vote. If two out of three say "anomaly," that is your answer with 66.7% confidence. If all three agree, you are at 100%.

The pseudocode algorithm looks like this:

```
Algorithm 1: Self-Consistency Multi-Perspective Reasoning
─────────────────────────────────────────────────────────
Input:  Log entry x, Expert roles R = {r₁, r₂, ..., r₅}, Temperature τ = 0.6
Output: Prediction ŷ, Confidence score c

 1  predictions ← []
 2  reasoning ← []
 3  for i = 1 to 3 do                          ▷ Generate 3 independent samples
 4      r ← random_select(R)                   ▷ Select random expert role
 5      prompt ← construct_expert_prompt(x, r)
 6      response ← LLM(prompt, τ)              ▷ Query with temperature 0.6
 7      yᵢ, rationaleᵢ ← parse_response(response)
 8      predictions.append(yᵢ)
 9      reasoning.append(rationaleᵢ)
10  end for
11  ŷ ← majority_vote(predictions)             ▷ NORMAL or ANOMALY
12  majority_count ← count(predictions, ŷ)
13  c ← majority_count / 3                     ▷ Confidence: 66.7% or 100%
14  return ŷ, c, reasoning
```

This pattern is not specific to any domain. You could use it for code review by asking a security expert, a performance engineer, and a maintainability specialist to each review the same pull request. The principle is the same: structured perspectives produce meaningful diversity that random sampling cannot.

## Having the model check its own work

Getting three expert opinions and taking a vote is a good start, but there is a second human practice we can borrow: peer review.

After the multi-perspective vote produces a prediction and its supporting reasoning, we prompt the same model again, this time as a "senior expert conducting a critical review." The model receives the original input, the prediction, the confidence score, and all three expert explanations, then renders one of three verdicts.

**CONFIRM** means the reviewer agrees. The original prediction stands.

**REJECT** means the reviewer found significant errors. A rejection comes with a revised prediction and an explanation of what the original analysis got wrong.

**UNCERTAIN** means the reviewer cannot commit either way. This flags the case for human review rather than forcing a potentially wrong answer.

```
Algorithm 2: Verifier Feedback System
─────────────────────────────────────
Input:  Initial prediction ŷ, Reasoning reasoning, Confidence c, Log entry x
Output: Verified prediction ŷ_final, Verification decision d

 1  verification_prompt ← construct_verifier_prompt(ŷ, reasoning, c, x)
 2  verification_prompt.use_thinking ← True     ▷ Enhanced thinking mode
 3  response ← LLM(verification_prompt, τ=0.2)  ▷ Lower temperature for consistency
 4  d, feedback ← parse_verifier_response(response)
 5  if d = CONFIRM then
 6      ŷ_final ← ŷ                             ▷ Accept original prediction
 7  else if d = REJECT then
 8      ŷ_final ← extract_refined_prediction(feedback)  ▷ Use verifier's refined prediction
 9  else if d = UNCERTAIN then
10      ŷ_final ← UNCERTAIN                     ▷ Flag as uncertain for human review
11  end if
12  return ŷ_final, d, feedback
```

Notice the temperature difference. The expert perspectives run at 0.6 to encourage diverse thinking. The verifier runs at 0.2 for focused, deterministic judgment. This mirrors how humans work: brainstorming meetings are loose and divergent, while the executive review that follows is tight and convergent.

## What happens in practice

Unanimous agreement among the three experts happened only 42% of the time. In the majority of cases, at least one expert disagreed with the other two. This is by design.

The verifier successfully resolved 87% of split decisions. In one concrete example from network traffic analysis, two experts classified a data point as normal while one flagged it as anomalous. The verifier looked at the reasoning, found that the two "normal" votes had failed to account for a suspiciously large packet size, and rejected their conclusion, correctly reclassifying the traffic as anomalous.

The computational cost is roughly four times a single inference call. For applications where correctness matters more than latency, this is a worthwhile trade. The hardest part is not the code. It is choosing good expert perspectives that are genuinely different and relevant to your domain.

In the [next post](/blog/when-smaller-beats-bigger/), we look at what happened when we evaluated ten different models through this pipeline, and why a 2-billion-parameter model outperformed one four times its size.

The SCARLOG framework is available at [github.com/rflorenc/SCARLOG](https://github.com/rflorenc/SCARLOG).
