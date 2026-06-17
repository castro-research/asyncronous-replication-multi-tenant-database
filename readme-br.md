# Objetivo

Transformar um problema de replicação de dados em um ambiente distribuído em um modelo formal, descrevendo a topologia, o modelo de consistência e as restrições sob as quais a replicação deve operar baseado em um contexto. O objetivo é criar um entendimento claro dos desafios envolvidos na replicação de dados entre bancos de dados distribuídos e fornecer uma base para discutir soluções potenciais.

Isso vai levantar alguns desafios, como inserção, atualização e exclusão de dados, com chaves estrangeiras com base citado em [Foreign Key Constraints to Maintain Referential Integrity in Distributed Database in Microservices Architecture](https://thesai.org/Publications/ViewPaper?Volume=16&Issue=6&Code=IJACSA&SerialNo=96).

Ao longo do processo, eu vou adicionar outras referências academicas e técnicas relevantes para o problema, para fornecer um contexto mais amplo e fundamentar as decisões de modelagem.

# Context

Baseado em um cenário real de banco de dados distribuídos por tenants, onde cada tenant tem um banco de dados local, mas há uma necessidade de replicar algumas tabelas de configuração do sistema a partir de um banco de dados central (DB0) para os bancos de dados dos tenants (DB1, DB2, DB3).

Cada banco de dados precisa ter uma cópia dessas informações, para que o sistema possa funcionar de maneira distribuída e independente.

<img src="./.assets/example.png" alt="Dbs" width="600"/>

O artigo talvez será publicado no ResearchGate, mas sem peso acadêmico, então o foco é mais na clareza e na descrição do problema do que em formalismos rigorosos.

# Código fonte

- [Experimento usando Broker para replicação de dados](https://github.com/alexcastrodev/thesis-data-replicator-broker)

- [Experimento usando Pub/Sub do PostgreSQL para replicação de dados](https://github.com/alexcastrodev/thesis-data-replicator-pubsub)