#set document(
  title: "(DRAFT) Asynchronous Replication Tables in a Distributed, Multi-Tenant Database Topology (?)",
  author: "Alexandro Castro",
)

#set page(
  paper: "a4",
  numbering: "1",
  margin: (x: 1.8cm, y: 2.2cm),
  columns: 2,
)

#set text(
  font: "New Computer Modern",
  size: 10.5pt,
  lang: "en",
)

#set par(justify: true, leading: 0.62em, first-line-indent: 1.2em)
#show heading: set block(above: 1.2em, below: 0.7em)
#set heading(numbering: "1.1")

#show raw.where(block: false): box.with(
  fill: luma(240),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 2pt,
)

// ---------- Topology diagram ----------
// A database node shows its two table classes: replicated (config) and tenant.
#let db-node(title, country, source: false) = box(
  fill: if source { luma(235) } else { white },
  stroke: 0.8pt + luma(120),
  radius: 4pt,
  inset: 0pt,
  clip: true,
)[
  #set align(center)
  #set par(leading: 0.4em)
  // header
  #block(width: 100%, inset: (x: 8pt, y: 5pt))[
    #text(weight: 700, size: 9.5pt)[#title] #h(3pt)
    #text(size: 7pt, fill: luma(70))[#country]
  ]
  #line(length: 100%, stroke: 0.6pt + luma(170))
  // table classes
  #grid(
    columns: 1,
    inset: (x: 4pt, y: 3.5pt),
    stroke: (y: 0.4pt + luma(210)),
    [
      #text(size: 7.5pt)[replicated tables]
      #h(0.5em)
      #text(size: 6pt, fill: rgb("#1a6b1a"), weight: 600)[#if source [read\u{2011}write] else [read\u{2011}only]]
    ],
    [
      #text(size: 7.5pt)[tenant tables]
      #h(0.5em)
      #if source {
        text(size: 6pt, fill: luma(150))[—]
      } else {
        text(size: 6pt, fill: rgb("#b54708"), weight: 600)[read\u{2011}write]
      }
    ],
  )
]

#let topology-diagram = {
  set text(size: 9pt)
  align(center)[
    #stack(
      dir: ttb,
      spacing: 0pt,
      // Source node
      box(width: 46%, db-node("DB0", "France · source", source: true)),
      // vertical stub from source
      line(length: 10pt, angle: 90deg, stroke: 1pt + luma(120)),
      // horizontal bus spanning the three replicas
      box(width: 88%)[
        #line(length: 100%, stroke: 1pt + luma(120))
      ],
      // three drop arrows into the replicas
      box(width: 88%)[
        #grid(
          columns: (1fr, 1fr, 1fr),
          ..range(3).map(_ => align(center,
            line(length: 10pt, angle: 90deg, stroke: 1pt + luma(120))))
        )
      ],
      v(2pt),
      // replica row
      box(width: 100%)[
        #grid(
          columns: (1fr, 1fr, 1fr),
          gutter: 6pt,
          ..(("DB1", "Portugal"), ("DB2", "Spain"), ("DB3", "Portugal"))
            .map(((n, c)) => db-node(n, c))
        )
      ],
    )
    #v(4pt)
    #text(size: 7.5pt, fill: luma(90), style: "italic")[
      Only replicated tables flow from DB0; tenant tables stay read-write locally.
    ]
  ]
}

// ---------- Title block + abstract (span both columns) ----------
#place(top, scope: "parent", float: true)[
  #align(center)[
    #block(text(weight: 700, size: 17pt)[
      Asynchronous Replication of Configuration Tables \
      in a Distributed, Multi-Tenant Database Topology
    ])
    #v(0.6em)
    #text(size: 11pt)[Alexandro Oliveira #h(0.3em) #text(size: 9pt)[(#link("mailto:alexandro.oliveira@cs.cruzeirodosul.edu.br")[alexandro.oliveira\@cs.cruzeirodosul.edu.br])]]
    #v(0.2em)
  ]

  #v(0.8em)

  #align(center)[
    #block(width: 80%)[
      #set par(justify: true, first-line-indent: 0em)
      #set text(size: 9.5pt)
      *Abstract.* This work models a data-replication problem in a distributed
      environment. A source database holds system-wide configuration data that must be available
      in every regional database so that each node can operate independently. We
      describe the topology, the consistency model, and the constraints under which
      replication must hold, and we discuss the open design question of how to handle
      deletions that may leave orphaned tenant-referencing rows. The system targets a
      eventual consistency model with a uniform schema across all nodes and
      asynchronous propagation from the source of truth.
    ]
  ]

  #v(0.6em)
  #line(length: 100%, stroke: 0.5pt + luma(180))
  #v(0.4em)
]

// ---------- Body ----------
= Introduction

In a monolithic architecture, where a single database instance serves the entire system, data replication is a concern.
PostgreSQL, for example, allows tenant isolation through separate databases (logical database within the same instance), or schemas.

Another challenge in asynchronous data replication involves maintaining referential integrity when replicated tables contain foreign key relationships. 
Update and delete operations may lead to temporary inconsistencies across distributed databases due to replication delays, making it difficult to enforce foreign key constraints consistently in a microservices environment @kanwal2025.

This research utilizes an experimental case study methodology. The experimental artifacts and services developed for this study will be implemented using Ruby on Rails and event-driven architectural principles, enabling the reproduction of realistic microservices scenarios and the analysis of different replication strategies and architectural alternatives.

The results of this study will provide insights and proof-of-concept are presented in this work.

= Context

We maintain a database in France that stores general information relevant to the
system setup and configuration: users, manufacturers, suppliers, and similar
shared entities. Each regional database must hold a *copy* of this information so
that the system operates in a distributed and independent fashion. In addition to
the replicated configuration data, each node stores the raw and analytical data
belonging to its own tenant.

#figure(
  topology-diagram,
  caption: [Replication topology: the source database (DB0) propagates configuration
  data to the regional databases, each of which also holds its own tenant data.],
) <fig-topology>

= System Model

For brevity we refer to the participating databases as follows:

#table(
  columns: (auto, 1fr),
  align: (left, left),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  table.header([*Node*], [*Role*]),
  [DB0], [França, fonte de verdade para dados replicados],
  [DB1, DB3], [Fisicamente em Portugal],
  [DB2], [Fisicamente em Espanha],
)

A DB0 é o único escritor para as tabelas de configuração replicadas. Todos os outros
nós são réplicas de leitura em relação a esses dados, enquanto permanecem proprietários
completos de seus próprios dados específicos do Tenant.

Uma clara separação de propriedade distingue as duas classes de dados em cada nó:

#table(
  columns: (auto, auto, auto),
  align: (left, left, left),
  stroke: 0.5pt + luma(200),
  inset: 6pt,
  table.header([*Table class*], [*On DB0*], [*On DB1, DB2, DB3*]),
  [Replicated (configuration)], [read-write], [read-only],
  [Tenant], [n/a], [read-write],
)

As tabelas replicadas *nunca são escritas diretamente* em um nó de tenant. A única
entidade que pode modificá-las é o DB0, que então propaga a mudança para os nós
subsequentes; no DB1, DB2 e DB3 essas tabelas são estritamente somente leitura.
Por outro lado, as tabelas de propriedade do tenant são somente leitura e escrita
apenas no nó que as possui, e não estão sujeitas à replicação.

= Limitações e Barreiras

The replication mechanism operates under the following constraints:

+ *Weak consistency.* We do not need to guarantee that the data is synchronized
  across all databases at the same instant; we only need to guarantee that every
  database eventually holds a copy of the tenant's data.

+ *Uniform schema.* The schema must be uniform across all databases so that
  replication works correctly.

+ *Tenant-referencing foreign keys.* Tables considered replicable may carry
  foreign keys into tenant data. For example, a replicated `Record` table may have a foreign key into a tenant-owned `Tenant` table.

+ *Asynchronous synchronization.* When a row is inserted or modified in DB0, the
  change must be propagated to the other databases asynchronously.

+ *Single writer for replicated data.* Replicated tables are written exclusively
  on DB0; on the tenant nodes (DB1, DB2, DB3) they are read-only. No tenant node
  may write directly to a replicated table; all changes originate at DB0 and
  flow downstream. Only the tenant-owned tables are read-write, and only on their
  owning node.


= Replicação por Assinatura de Eventos



= (DRAFT) Investigação Futura

A central open question concerns deletions. When a row is deleted in DB0, the
same row should be deleted in DB1, DB2, and DB3. If that row is referenced by a
foreign key on one of the tenants, several strategies are possible:

- *Prevent* the deletion while references exist;
- Perform a *distributed transaction* across the affected nodes; or
- Delete the row anyway and *tolerate orphaned* tenant-referencing data.

#bibliography("refs.bib", title: "References", style: "ieee")
