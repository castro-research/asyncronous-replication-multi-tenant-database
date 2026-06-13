# Objective

The idea of this project is to simulate a data replication problem in a distributed environment.

# Context

I have a database in France where I store general information relevant to the setup, and system configurations. Users, Manufacturers, Suppliers, etc.

Each database will need to have a copy of this information, so the system can work in a distributed and independent way.

<img src="./.assets/example.png" alt="Dbs" width="600"/>

Each database will have the copy of the information plus the raw and analytical data belonging to the tenant.

# Aliases

- DB0 - France's DB (Source of truth for the data being replicated)
- DB1 - Portugal's DB
- DB2 - Spain's DB
- DB3 - Portugal's DB

# Limitations / Edges

1. We don't need to guarantee that the data is synced across the databases at the same time, but we need to guarantee that each database has a copy of the tenant's data. (Low consistency)

2. The schema needs to be uniform across the databases, so the replication works correctly.

3. The tables considered replicable can have a foreign key to the tenant's data. (i.e. the manufacturers table can have a foreign key to the tenant table)

4. Sync needs to be asynchronous, meaning when a piece of data is inserted/changed in DB0, it needs to be replicated to the other databases.

5. The Tenant DBs have replica tables (read-only), but other data is read-write, meaning it can be changed and doesn't need to be replicated to the other databases.

# Future

1. When deleting a piece of data in DB0, it should delete the same data in DB1, DB2 and DB3, and have a foreign key in one of the tenants. What do we do?

Block it? Do a distributed transaction? Or just delete the data and leave the data orphaned?
