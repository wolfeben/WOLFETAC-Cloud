# FruitBank Cloud API

FruitBank is a separate module inside the WOLFETAC Cloud Business Central extension. It uses only the FruitBank object band (`58500-58699`) and does not depend on SAL pages, permissions or workflows.

## First vertical slice: portal sites

The first slice establishes a safe, testable connection from the FruitBank portal backend to Business Central:

- TAC staff maintain the logical FruitBank sites on page **FruitBank Portal Sites** (`58500`).
- Each logical site maps to a Business Central Location Code.
- The versioned API exposes active sites through a temporary projection rather than exposing the management table directly.
- The API is read-only. It cannot insert, modify or delete sites.
- No stock, pallet, transfer, sales, receipt, posting or financial records are changed.

### Endpoint

```text
GET https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment-name}/api/tac/fruitBank/v1.0/companies({company-id})/portalSites
```

Example response shape:

```json
{
  "value": [
    {
      "id": "00000000-0000-0000-0000-000000000000",
      "code": "EXOTICS",
      "displayName": "Exotics",
      "locationCode": "EXOTICS",
      "stateCode": "WA",
      "active": true,
      "lastModifiedDateTime": "2026-08-28T00:00:00Z"
    }
  ]
}
```

The `id` is the stable Business Central SystemId. Front-end and backend code should store/use it as the site identifier; display names and location codes are not immutable keys.

## Authentication boundary

The browser must never call Business Central directly and must never receive a Business Central access token.

```text
DC user -> FruitBank website/backend -> Microsoft Entra service application -> Business Central API
```

Use a confidential, single-tenant Entra application for the backend-to-BC connection. Assign that application only the **FBK PORTAL API** Business Central permission set and scope it to the approved test company. Keep its certificate or client credential in backend secret storage.

Do not assign `SUPER`, `D365 AUTOMATION`, `AvocadosAPI`, SAL permissions or the legacy scanner permission sets to the FruitBank service application.

## Acceptance check in TAC_TEST/TestProd

1. Package the extension successfully against the current Business Central 28 symbols.
2. Publish only to the approved sandbox after explicit approval.
3. Add two sites on page **FruitBank Portal Sites**, one active and one inactive.
4. Obtain a backend service token and call `portalSites`.
5. Confirm the active site is returned and the inactive site is not.
6. Confirm `POST`, `PATCH` and `DELETE` are rejected.
7. Confirm the service application cannot access standard customer/item APIs, SAL endpoints or BC administration pages.

## Deliberately not included yet

- external-user records, roles and per-site assignments;
- pallet and stock projections, including both pallet count and tray/unit count;
- consignment, receival, return, damage, transfer or sales workflows;
- write commands or posting;
- production deployment.

The next read slice should add actor/site access records and a stock projection that reports both physical pallet quantity and tray/unit quantity. Its source tables and pallet-to-tray conversion rules must be confirmed before those permissions are added.
