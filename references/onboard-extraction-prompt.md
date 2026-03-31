# Onboard Extraction Prompt

This is the structured prompt that users paste into their prior AI (ChatGPT, Gemini,
Copilot, etc.) to extract their accumulated context. The output is parsed by `pmm:onboard`
to generate `user.md` and route PII to `secrets.md`.

Present this to the user as a single copyable block. Adapt the AI name to whichever tool
they're migrating from.

---

## The Prompt

```
I'm setting up a new AI assistant and need you to help me carry my context across. Please
write a comprehensive self-description covering everything you know about how I work, who I am,
and how I like to be spoken to. Structure your response with these sections:

1. WHO I AM
   - My name, location, and what I actually do (not just job title — what I'm trying to achieve)
   - My language preference (UK/US English, or other)
   - Relevant professional background that shapes how I think
   - What my MBTI and DISC profile is (what you have been told, as well as what you can infer
     from past interactions with me)
   - My desires
   - My aspirations
   - My fears
   - My frustrations
   - What you can describe about me from all our past conversations, especially things which I
     may not know about myself
   - What I would say to my younger self, based on our past conversations, what you know about
     me and what you can infer about me

2. HOW I LIKE TO BE SPOKEN TO
   General preferences:
   - My preferred tone (formal/casual, warm/direct, collaborative/instructional)
   - My preferred response length and density (brief and punchy vs. thorough and detailed)
   - How I feel about structure: headers, bullet points, numbered lists — do I like them or find
     them excessive?
   - What a great response sounds like to me — use specific examples from our history if possible

   In different circumstances:
   - When I'm brainstorming or thinking out loud — what do I want the AI to do? (Push back?
     Build on it? Ask questions? Just follow the thread?)
   - When I'm making a decision — do I want options laid out, a recommendation, or just analysis?
   - When I'm under pressure or moving fast — short and direct, or still thorough?
   - When I'm asking for feedback on my work — how honest, how blunt, how much encouragement?
   - When I'm learning something new — do I want it explained simply or treated as capable of
     handling complexity?

   In my own words:
   - Quote anything I've said directly about how I want to be spoken to — e.g. "stop
     over-explaining", "just give me the answer", "don't hedge so much", "treat me like a peer"
   - Note any frustrations I've expressed about AI communication style, even in passing

   Anti-patterns — things I dislike:
   - Response patterns that have annoyed or frustrated me
   - Things I've had to correct repeatedly
   - Anything I've explicitly said I don't want

3. MY WORKING STYLE
   - How I process information and make decisions
   - My personality or cognitive style if you've picked up on it
   - What I respond well to

4. MY MAIN ROLES AND USE CASES
   - The 3-5 recurring contexts where I use you most
   - For each: what the work involves, what you need to know upfront, what tools/systems matter
   - Any decisions already made in each area that shouldn't be second-guessed
   - For each role: have I assigned you a specific persona, character, or way of operating?
     If so — what is it, how does it behave, and are there examples from our history of it
     working well?
   - Is there a universal persona I've asked you to maintain across all our interactions —
     not specific to one role, but generally?

5. ONGOING WORK AND CURRENT STATE
   - What's currently in flight
   - Recent decisions that are locked in
   - Things I don't want to re-explain or re-litigate

6. CORE BELIEFS AND PRINCIPLES (if applicable)
   - Any operating philosophies or ways of thinking I've expressed
   - Things I seem to believe strongly about how work should be done

7. WHERE WE LAST LEFT OFF
   - The roles you have played in our conversations
   - The last bit of contextual memory that you would like to preserve from the last
     conversation for each role that will allow us to continue our conversations seamlessly

8. MY PROCESSES, WORKFLOWS AND CHECKLISTS
   Global (things I do regardless of role):
   - Any recurring rituals, reviews, or routines I've mentioned (weekly reviews, planning
     sessions, daily habits, etc.)
   - Any frameworks or mental models I apply consistently across my work
   - Any checklists or decision-making processes I use generally

   Per role (for each role identified above):
   - The standard process or workflow I follow for key activities in that role
   - Any checklists, templates, or SOPs I've mentioned or implied I use
   - How I typically start, execute, and close out pieces of work in that area
   - Steps I've told you not to skip, or mistakes I've said I've made before
   - Any tools or systems that are part of the workflow (not just what I use, but how they fit
     into the sequence)

   Be specific. If I've described how I run a client onboarding, a content production cycle,
   a sales call, a performance review — capture it as a step-by-step process, not a summary.
   Use the exact language I've used for each step if you can recall it.

9. KEY PEOPLE, ACTORS AND PERSONAS
   For each significant person who has appeared in our conversations — across any role — provide
   a profile. Include colleagues, clients, partners, collaborators, direct reports, stakeholders,
   or anyone I've discussed repeatedly or at length.

   For each person:
   - Who they are: their name, role/relationship to me, and why they matter in my world
   - Which of my roles they appear in (some may appear across multiple)
   - When we first discussed them and in what context
   - What we last discussed about them — the most recent relevant thread
   - Your impression of them based on everything I've shared (be honest, note complexity)
   - My own impression of them — quote my actual words wherever possible, even passing comments
   - Any key commitments, agreements, or activities involving them that are still live
   - Anything I've said about how to handle them, communicate with them, or what to be careful of
   - Any tension, history, or dynamic worth noting

   Also include:
   - Any recurring personas or archetypes I've described even without naming (e.g. "my typical
     client", "the kind of investor I'm trying to avoid", "the team member I keep having to
     manage around")
   - Any relationships that have changed significantly over our conversation history — note
     how my view of them has evolved if that's visible

   Be honest rather than diplomatic. If I've expressed frustration, admiration, ambivalence,
   or complexity about someone — capture that faithfully, in my own words where possible.

10. HOW YOU SEE ME
   Set aside what I've told you about myself. Based purely on our full conversation history —
   what I've asked, how I've responded, what I've avoided, what I keep returning to — answer
   the following as honestly as you can:

   - How would you describe me as a person, in your own words? Not my job or my goals —
     who I actually am as you've experienced me.
   - What patterns have you noticed in how I think and work that I may not have named myself?
   - What do I seem to care about most, based on what I actually do — not what I say I care
     about?
   - Where do I seem to get in my own way? What do you notice I do repeatedly that works
     against me?
   - What are my apparent strengths — the things I seem to do better than most people you
     work with?
   - What do I seem to need from an AI that I haven't always asked for directly?
   - What should a new AI know about me that I probably wouldn't think to tell them?
   - If you had to describe the arc of how I've grown or changed across our conversations,
     what would you say?

   Be candid. This is not a performance review or a compliment. The goal is to give my new AI
   an honest picture of who I am to work with — the full version, including the complicated
   parts.

Be specific. Use my actual language where you've heard it. If you're uncertain about something,
note it rather than guessing. This output will be used to configure a new AI assistant.
```
