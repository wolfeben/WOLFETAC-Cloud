# WOLFETAC Cloud object ID registry

Object IDs are unique per AL object type. This registry reserves domain bands by convention so that SAL, FruitBank, shared integration, and tests do not drift into one another.

## Domain allocation

| IDs | Owner | Rule |
|---|---|---|
| 58000-58499 | SAL production | SAL Cloud planning, monitoring, APIs, permissions, install and upgrade objects |
| 58500-58699 | FruitBank production | Reserved; do not use for SAL |
| 58700-58799 | WOLFETAC shared | Shared integration, telemetry and genuinely cross-domain objects only |
| 58800-58949 | Test extensions | Separate test apps; never include test objects in the production app |
| 58950-58999 | Project reserve | Do not allocate without an architecture decision |

The former 59006/59007 Cloud prototype IDs are retired. The last two digits are retained in the approved Cloud page IDs below.

## FruitBank pages

| ID | Name | State |
|---|---|---|
| 58500 | FruitBank Portal Sites | Implemented first management page |
| 58650 | FBK Portal Site API | Implemented read-only `portalSites` API v1.0 |
| 58651-58679 | FruitBank API pages | Reserved for versioned portal endpoints |

## FruitBank tables

| ID | Name | State |
|---|---|---|
| 58500 | FBK Portal Site | Implemented TAC-managed logical site to BC Location mapping |
| 58501 | FBK Portal Site Buffer | Implemented temporary API projection buffer |
| 58502-58549 | FruitBank configuration and access tables | Reserved |
| 58550-58599 | FruitBank command, staging and audit tables | Reserved |

## FruitBank codeunits

| ID | Name | State |
|---|---|---|
| 58500 | FBK Read Projection | Implemented active-site projection |
| 58501-58549 | FruitBank read, access and validation codeunits | Reserved |
| 58550-58599 | FruitBank command and audit codeunits | Reserved |

## FruitBank permission sets

| ID | Name | State |
|---|---|---|
| 58680 | FBK PORTAL READ | Implemented non-assignable read component |
| 58681 | FBK PORTAL STAGE | Reserved for the non-posting receipt staging capability |
| 58682 | FBK PORTAL API | Implemented service-application permission set |
| 58683 | FBK PORTAL ADMIN | Implemented TAC internal administration permission set |

## SAL pages

| ID | Name | State |
|---|---|---|
| 58000 | SAL Setup | Implemented setup card |
| 58001 | SAL Plans | Implemented plan-version list |
| 58002 | SAL Plan Details | Implemented supporting plan card |
| 58003 | SAL Plan Pallets | Implemented planner ListPart |
| 58004 | SAL Pallet Components | Implemented selected-pallet ListPart |
| 58005 | SAL Plan Events | Implemented read-only activity ListPart |
| 58006 | SAL Stock & Logistics Monitor | Implemented as the searchable Packing & Logistics Monitor |
| 58007 | SAL Stock & Logistics Planner | Implemented interactive versioned planner card |
| 58008 | SAL Unconsigned Pallets | Reserved |
| 58009 | SAL Allocation Exceptions | Reserved |
| 58010 | SAL Pallet Templates | Reserved |
| 58011 | SAL Template Rules | Reserved |
| 58012 | SAL Product Groups | Implemented fill-group setup list |
| 58013 | SAL Product Group Members | Implemented eligible SKU and per-template limit setup |
| 58014 | SAL Integration Status | Reserved |
| 58015 | SAL Plan Sources | Implemented demand-and-routing ListPart |
| 58016 | SAL Freight & Arrivals Monitor | Implemented as a non-searchable supporting freight-detail projection |
| 58017 | SAL Freight Load Card | Reserved pending confirmation of the authoritative freight source and ownership |
| 58018 | SAL Plan Fill Members | Implemented versioned per-order fill-member snapshot list |
| 58150-58179 | SAL API pages | Reserved for versioned integration endpoints; not interactive pages |

Packing Wall and Packing Facility Operator remain in the on-premises extension and receive no IDs from this Cloud range.

## SAL tables

| ID | Name | State |
|---|---|---|
| 58000 | SAL Setup | Implemented singleton |
| 58001 | SAL Plan Header | Implemented |
| 58002 | SAL Plan Source | Implemented |
| 58003 | SAL Plan Pallet | Implemented |
| 58004 | SAL Plan Component | Implemented |
| 58005 | SAL Plan Event | Implemented |
| 58006 | SAL Pallet Template | Reserved |
| 58007 | SAL Template Rule | Reserved |
| 58008 | SAL Product Group | Implemented marketer-specific fill-group template |
| 58009 | SAL Product Group Member | Implemented unlimited eligible SKU membership and default limits |
| 58010 | SAL Allocation Exception | Reserved |
| 58011 | SAL Sync State | Reserved |
| 58012 | SAL Operation Request | Reserved |
| 58013 | SAL Plan Fill Member | Implemented versioned eligible SKU and per-order limit snapshot |

## SAL enums

| ID | Name | State |
|---|---|---|
| 58000 | SAL Plan Status | Implemented |
| 58001 | SAL Source Type | Implemented |
| 58002 | SAL Execution Route | Implemented |
| 58003 | SAL Facility Work Type | Implemented |
| 58004 | SAL Pallet Type | Implemented |
| 58005 | SAL Acknowledgement Type | Reserved |
| 58006 | SAL Allocation Status | Reserved |
| 58007 | SAL Integration Status | Reserved |
| 58008 | SAL Exception Type | Reserved |
| 58009 | SAL Fulfilment Mode | Implemented Exact SKU, Fill Group and Exact + Fill modes |

Do not encode TAC and Costa as enum values until the authoritative upstream marketer field and extensibility requirement are confirmed.

## SAL codeunits

| ID | Name | State |
|---|---|---|
| 58000 | SAL Demand Management | Implemented released Sales/Transfer demand selection and source snapshots |
| 58001 | SAL Plan Management | Implemented validation, release and safe version-copy lifecycle |
| 58002 | SAL Plan Validation | Implemented release validation and quantity/routing rules |
| 58003 | SAL Publish Management | Reserved |
| 58004 | SAL Sales Adapter | Reserved |
| 58005 | SAL Transfer Adapter | Reserved |
| 58006 | SAL Allocation Management | Implemented Draft fill conversion, fill allocation, adjustment and audit rules |
| 58007 | SAL Finish Short Management | Reserved |
| 58008 | SAL Integration Outbound | Reserved |
| 58009 | SAL Integration Inbound | Reserved |
| 58010 | SAL Reconciliation | Reserved |
| 58011 | SAL Install | Reserved |
| 58012 | SAL Upgrade | Reserved |

## SAL permission sets

| ID | Name | State |
|---|---|---|
| 58000 | SAL VIEW | Implemented |
| 58001 | SAL PLANNER | Implemented |
| 58002 | SAL ADMIN | Implemented |
| 58003 | SAL INTEGRATION | Reserved |

## SAL test extension

A separate test app, `WOLFETAC Cloud Tests`, lives under `Test/SAL` and depends on the production app. It uses codeunit IDs from the 58800-58949 test band.

| ID | Name | State |
|---|---|---|
| 58800 | SAL Plan Model Tests | Implemented; validates line/pallet number sequencing, source-line referential checks and pallet quantity roll-up |
| 58801 | SAL Fill Group Tests | Implemented fill conversion, caps, marketer, mixed-pallet, adjustment and revision tests |

## Allocation rules

1. Reserve the object here before creating it.
2. Record both object type and ID; IDs may repeat between different object types.
3. Never recycle an ID after an object has been published to any tenant.
4. Obsolete published objects using AL obsoletion properties and an upgrade path; do not delete them casually.
5. Check downloaded dependency symbols and installed tenant extensions before the first publication.
6. Any change to the domain bands requires a recorded architecture decision.
