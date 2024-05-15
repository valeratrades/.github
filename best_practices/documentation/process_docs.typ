There are many possible ways to get some code into the main branch. Pick one, and spell it out in an .md file explicitly:

- Are feature branches pushed to the central repository, or is anyone works off their fork? I find forks work better in general as they automatically namespace everyone’s branches, and put team members and external contributors on equal footing.

- If the repository is shared, what is the naming convention for branches? I prefix mine with matklad/.

- You use #link("https://graydon2.dreamwidth.org/1597.html")[_not rocket-science rule (NRSR)_].

- Who should do code review of a particular PR? A single person, to avoid bystander effect and to reduce notification fatigue. The reviewer is picked by the author of PR, as that’s a stable equilibrium in a high-trust team and cuts red tape.

- How the reviewer knows that they need to review code? On GitHub, you want to _assign_ rather than _request_ a review. Assign is level-triggered — it won’t go away until the PR is merged, and it becomes the responsibility of the reviewer to help the PR along until it is merged (_request review_ is still useful to poke the assignee after a round of feedback&changes). More generally, code review is the highest priority task — there’s no reason to work on new code if there’s already some finished code which is just blocked on your review.

- What is the purpose of review? Reviewing for correctness, for single voice, for idioms, for knowledge sharing, for high-level architecture are choices! Explicitly spell out what makes most sense in the context of your project.

- Meta process docs: positively encourage contributing process documentation itself.
