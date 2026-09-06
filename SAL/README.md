# TAC Stock & Logistics (SAL)

This is the canonical Cloud Business Central project for TAC Stock & Logistics.

- Project root: `D:\WOLFETAC\Cloud\SAL`
- App ID: `1802aae7-3e0b-4d5d-89c2-0ec78ca9032f`
- Publisher: `WOLFE`
- Object range: `58000-58499`
- Test project: `D:\WOLFETAC\Cloud\Test\SAL`

Primary user pages:

- Page 58006 — Packing & Logistics Monitor (read-only operational journey)
- Page 58007 — Stock & Logistics Planner (transactional planning)

Page 58016 is retained as a non-searchable supporting freight-detail projection. On-premises Packing Wall, operator, scanner, Unconsigned and physical completion remain outside this Cloud app until the versioned facility integration is implemented.

Compile and publish from this folder only. Never publish the preserved `D:\WOLFETAC\Cloud\App` copy or an old combined `WOLFETAC Cloud` package.
