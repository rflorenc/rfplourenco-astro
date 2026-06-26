---
title: "Three Experts, One Model: Making Small Language Models Reliable"
description: "How multi-perspective prompting and self-verification can make small language models produce reliable predictions without scaling to larger, more expensive models."
date: 2026-06-27
tags: ["ai", "python"]
---

When you have a serious medical concern, you do not rely on a single opinion. You see a specialist, maybe two. A cardiologist focuses on your heart. A neurologist focuses on your nervous system. A general practitioner looks at the whole picture. If two out of three agree on a diagnosis, you feel more confident. If all three agree, you are fairly certain.

This is the core idea behind self-consistency in language models. But the technique was originally designed for models with hundreds of billions of parameters, the kind that cost thousands of dollars per hour to run. In our research, we adapted it to work with models small enough to run on a single consumer GPU, and the results surprised us.

## The single-shot problem

Most applications that use language models today work like this: you send a prompt, you get one answer, you use it. This is called single-shot inference, and it has an obvious weakness. You are trusting one roll of the dice.

Small language models, roughly 1.5 to 8 billion parameters, make this worse. They are fast and cheap to run, but they are more prone to confident-sounding mistakes than their larger counterparts. A small model might classify something as normal when it is clearly anomalous, and it will do so with the same assertive tone as when it is correct. There is no built-in signal that says "I might be wrong about this one."

The natural instinct is to reach for a bigger model. But bigger models need expensive hardware, more energy, and more time. For many real-world applications like monitoring systems, edge computing, and organizations without GPU clusters, that is not an option.

So the question becomes: can we make a small model more reliable without replacing it with a bigger one?

## Asking the same model three different questions

The original self-consistency technique, proposed by Wang et al. in 2022, works by asking a large model the same question multiple times at a higher temperature. Temperature is a setting that introduces randomness into the model's output. You get several different reasoning paths, then take a majority vote on the final answer. The diversity comes from the randomness.

This does not work well with small models. When you increase the temperature on a 2-billion-parameter model, you do not get creative diversity. You get incoherent noise. The model does not have enough internal knowledge to explore meaningfully different reasoning paths on its own.

Our approach replaces randomness with structure. Instead of asking the same question three times and hoping for different reasoning, we ask three different questions about the same input. Each question frames the problem from a different expert perspective.

Imagine you are looking at unusual network traffic and you want to know if it is an attack. Instead of asking a general "is this anomalous?" three times, you could ask a network security expert to look for attack signatures and suspicious ports. You could ask a network administrator to assess whether the traffic patterns are operationally normal. You could ask a threat hunter to consider what an attacker might be trying to accomplish.

Each perspective examines different evidence, applies different domain knowledge, and reaches its own conclusion. Then you take the majority vote. If two out of three say "anomaly," that is your answer with 66.7% confidence. If all three agree, you are at 100%.

The key difference from the original technique is that the reasoning diversity comes from the prompt structure, not from random sampling. This works because even a small model can adopt different analytical frames when explicitly told to. It just cannot discover them on its own through temperature variation.

The formal algorithm looks like this:

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

This pattern is not specific to any domain. You could use it for code review by asking a security expert, a performance engineer, and a maintainability specialist to each review the same pull request. You could use it for financial document review by consulting a compliance officer, an auditor, and a risk analyst. The principle is the same: structured perspectives produce meaningful diversity that random sampling cannot.

## Having the model check its own work

Getting three expert opinions and taking a vote is a good start, but there is a second human practice we can borrow: peer review.

After a research team reaches a conclusion, a senior colleague reviews their work. This reviewer is not looking at the raw data fresh. They are evaluating the reasoning process. Did the team consider the right evidence? Is their logic sound? Are there alternative explanations they missed?

We implemented exactly this as a second stage. After the multi-perspective vote produces a prediction and its supporting reasoning, we prompt the same model again, this time as a "senior expert conducting a critical review." The model receives the original input, the prediction, the confidence score, and all three expert explanations, then renders a verdict.

The verdict is one of three options.

**CONFIRM** means the reviewer agrees. The analysis is well-reasoned and the conclusion follows from the evidence. The original prediction stands.

**REJECT** means the reviewer found significant errors or misinterpretations. A rejection comes with a revised prediction and an explanation of what the original analysis got wrong.

**UNCERTAIN** means the reviewer sees merit in multiple interpretations and cannot commit either way. This flags the case for human review rather than forcing a potentially wrong answer.

The formal algorithm for the verification stage:

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

That third option is what makes this pattern production-ready. In any real system, there are ambiguous cases where automated decisions are dangerous. Having an explicit "I don't know" output is far better than a coin-flip answer delivered with false confidence.

## The temperature trick

There is one subtle but important implementation detail. The verification step runs at a lower temperature of 0.2 compared to the expert perspectives at 0.6.

Temperature controls how "creative" versus "deterministic" a model's output is. Higher temperature produces more varied, exploratory responses. Lower temperature produces more focused, consistent ones.

This creates what we call a temperature differential funnel. The first stage deliberately encourages diverse thinking. You want your three experts to disagree sometimes, because that is where the interesting signal is. The second stage deliberately encourages convergent thinking. You want your reviewer to be careful, methodical, and consistent.

It mirrors how humans work. Brainstorming meetings are loose and divergent. The executive review that follows is tight and convergent. Using the same temperature for both stages would either make the experts too conservative or make the verifier too unpredictable.

## What happens in practice

When we ran this two-stage pipeline across thousands of test samples, the results told a clear story.

Unanimous agreement among the three experts happened only 42% of the time. In the majority of cases, at least one expert disagreed with the other two. This is by design. If all three always agreed, we would not need three perspectives.

The interesting part is what happens with those split decisions. The verifier successfully resolved 87% of them, either confirming the majority vote or rejecting it with a better answer. In one concrete example from network traffic analysis, two experts classified a data point as normal while one flagged it as anomalous. The verifier looked at the reasoning, found that the two "normal" votes had failed to account for a suspiciously large packet size, and rejected their conclusion, correctly reclassifying the traffic as anomalous.

Without the verifier, that would have been a missed detection. With only a single expert, there would have been no disagreement signal at all.

## Using this pattern in your own work

The two-stage pipeline is a general-purpose reliability layer that sits on top of any language model. It requires no fine-tuning, no additional models, and no specialized hardware. You are using the same model throughout, just prompting it differently at each stage.

The computational cost is roughly four times a single inference call: three expert perspectives plus one verification. For applications where correctness matters more than latency, this is a worthwhile trade. For real-time chat applications where speed is paramount, it probably is not.

The implementation is straightforward. Define your expert perspectives based on what different specialists would examine in your problem domain. Build structured prompts for each. Run them in parallel if your infrastructure allows it. Aggregate by majority vote. Then run the verification prompt with the collected reasoning.

The hardest part is not the code. It is choosing good expert perspectives. The perspectives need to be genuinely different and relevant to your domain. When in doubt, think about which human specialists you would actually consult for this type of decision, and model your prompts accordingly.

In the [next post](/blog/when-smaller-beats-bigger/), we look at what happened when we evaluated ten different models through this pipeline, and why a 2-billion-parameter model outperformed one four times its size.

This post is based on research conducted at the University of Leeds. The SCARLOG framework is available at [github.com/rflorenc/SCARLOG](https://github.com/rflorenc/SCARLOG).
