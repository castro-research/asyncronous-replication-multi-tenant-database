# Related Work — papers to evaluate

---

## HIGH priority — attack the core of the problem

- [ ] **2025 — Foreign Key Constraints to Maintain Referential Integrity in Distributed Database in Microservices Architecture** (IJACSA)
  - Closest and most recent. Compares shared DB / API validation / event-driven / Saga → maps onto your 3 deletion options.
  - https://thesai.org/Downloads/Volume16No6/Paper_96-Foreign_Key_Constraints_to_Maintain_Referential_Integrity.pdf
  - Evaluation:

- [ ] **2011 — Conflict-free Replicated Data Types** — Shapiro, Preguiça, Baquero, Zawirski (SSS)
  - Set CRDTs (2P-Set, OR-Set) model "deleting a replicated row without resurrecting it".
  - https://www.lip6.fr/Marc.Shapiro/papers/2011/CRDTs_SSS-2011.pdf
  - Evaluation:

- [ ] **2008 — Measuring Referential Integrity in Distributed Databases** — Ordonez & García-García
  - RI under incomplete/inconsistent content = your tolerated-orphan-rows scenario.
  - https://www.semanticscholar.org/paper/Measuring-referential-integrity-in-distributed-Ordonez-Garc%C3%ADa-Garc%C3%ADa/57ad68e9753957209310168b78d87dd6f928b145
  - Evaluation:

- [ ] **1987 — Epidemic Algorithms for Replicated Database Maintenance** — Demers et al. (PODC)
  - "Death certificates": propagating deletions without resurrecting data = your open problem.
  - Evaluation:

---

## MEDIUM priority — frame the model (replication + weak consistency)

- [ ] **2020 — Keeping CALM: When Distributed Consistency is Easy** — Hellerstein & Alvaro (CACM)
  - When you need coordination (2PC) vs. when you can tolerate orphans. Frames the deletion decision.
  - Evaluation:

- [ ] **2009 — Eventually Consistent** — Vogels (CACM)
  - Formally defines your weak/eventual consistency constraint.
  - Evaluation:

- [ ] **2005 — Optimistic Replication** — Saito & Shapiro (ACM Computing Surveys)
  - Survey covering the whole lazy/asynchronous model. Good anchor for Related Work.
  - Evaluation:

- [ ] **1997 — Flexible Update Propagation for Weakly Consistent Replication** — Petersen et al. (SOSP)
  - Bayou: anti-entropy + version vectors for your asynchronous propagation.
  - https://www.semanticscholar.org/paper/Flexible-update-propagation-for-weakly-consistent-Petersen-Spreitzer/9df8ab278cedbbf9552aa611333bb5f26d7b5f71
  - Evaluation:

- [ ] **1997 — Protocols for Integrity Constraint Checking in Federated Databases** — Grefen & Widom
  - Incremental checking of referential constraints in federated databases.
  - Evaluation:

- [ ] **1995 — Managing Update Conflicts in Bayou** — Terry et al. (SOSP)
  - Weakly consistent replicas that converge.
  - https://www.scs.stanford.edu/nyu/03sp/sched/bayou.pdf
  - Evaluation:

---

## LOW priority — foundational / context

- [ ] **199x — Practical Approaches to Maintaining Referential Integrity in Multidatabase Systems**
  - RI with replicated data, more generic.
  - https://www.academia.edu/544317/Practical_approaches_to_maintaining_referential_integrity_in_multidatabase_systems
  - Evaluation:

- [ ] **1996 — The Dangers of Replication and a Solution** — Gray, Helland, O'Neil, Shasha (SIGMOD)
  - Justifies why DB0 is single-writer (lazy primary-copy). Foundational but tangential.
  - https://cs-people.bu.edu/mathan/reading-groups/papers-classics/replicas.pdf
  - Evaluation:

- [ ] **1986 — Transaction Management in the R\* Distributed Database System** — Mohan et al. (TODS)
  - Two-phase commit — only relevant if you explore the "distributed transaction" option.
  - Evaluation:

---

**If you only read 4:** 2025 (IJACSA) · CRDT 2011 · Demers 1987 (death certificates) · CALM 2020.
