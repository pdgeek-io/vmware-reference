# Adoption Playbook

## How to Sell a University Research Computing Platform

This isn't a guide about infrastructure. It's a guide about removing friction from research and getting institutional buy-in for a shared, self-funding computing platform.

The technology is an implementation detail. What matters is the outcome: **a researcher's grant is approved on Friday, and Monday morning they have a compliant compute environment. No PO, no vendor calls, no 12-week procurement, no facilities request for power and cooling.**

---

## The Problem You're Solving

Every university has the same story:

- 100+ unmanaged servers scattered across labs and closets
- Hardware purchased with grant funds 7+ years ago, still running, unpatched
- No backups, no compliance documentation, no access controls
- A grad student set it up, graduated, and took the passwords with them
- IT gets blamed when it gets breached or dies
- Each department hoards infrastructure because "central IT is slow"
- Nobody knows what's running where, or whose grant paid for it

This is institutional risk hiding in plain sight.

---

## The Platform Pitch

### To the President

> "We're consolidating 100+ unmanaged, non-compliant servers into a shared research computing platform. It's grant-funded, self-sustaining, and reduces institutional risk. Researchers get faster access to computing. The university gets visibility, compliance, and a shrinking shadow IT footprint."

### To the CIO

> "I can give you visibility into shadow IT, reduce support burden, improve our compliance posture, and researchers pay for it with their own grant dollars. The platform grows as grants fund it."

### To the Research / Sponsored Programs Office

> "Every grant that requires NIST 800-171, data management plans, or access controls — this platform meets those requirements out of the box. Right now, PIs are self-certifying compliance on hardware we can't verify. This fixes that."

### To the PI / Researcher

> "Your grant is approved. What do you need? Compute, storage, compliance paperwork? It's here. Today. No shopping, no PO, no hardware to chase. Your team gets access, your grant gets charged, and when the grant ends we handle the rest."

---

## Speak Outcomes, Not Infrastructure

Cloud providers don't sell servers. They sell outcomes. AWS doesn't say "we have Xen hypervisors in Virginia." They say "deploy your application." The same principle applies here.

| Don't say | Say |
|---|---|
| VM provisioning | Your environment is ready |
| PowerScale NFS share | Your research storage is set up |
| NIST 800-171 compliant infrastructure | Your grant requirements are met |
| Chargeback reporting | Your grant spend is tracked |
| Resource pool with RBAC | Your team has access |
| Lifecycle management | We handle it when the grant ends |
| vSphere cluster with PowerStore | Research computing platform |

The fact that it's vSphere underneath is an implementation detail — same way S3 being object storage is an implementation detail. Nobody cares. They care that their files are there and their research can proceed.

**You're not selling infrastructure. You're selling time-to-research.**

---

## Overcoming University Politics

Departments hoard infrastructure because:

- "If I don't spend it, I lose it"
- "Central IT burned me before"
- "My dean controls my budget, not the CIO"
- "I built this, it's mine"

**You don't fight that. You route around it.**

### Don't Mandate — Attract

- Never force adoption. That breeds resentment.
- Don't start with governance or reporting. Start with value.
- Don't build a portal nobody asked for. Talk to the teams first.
- Make the platform so easy that using it is less work than doing it yourself.

### The "I Need to Tie My Grant to a Physical Box" Objection

This comes up constantly. It's usually a habit, not a requirement. What grant compliance actually requires:

- **Accountable spend** on allowable costs
- **Access controls** — who can touch the data
- **Data protection** — backups, encryption, disaster recovery
- **Audit trails** — who accessed what, when
- **Compliance frameworks** — NIST, ITAR, CUI, HIPAA depending on the grant

A researcher's lab server has none of that. The shared platform has all of it. A shared, secured, audited resource pool with chargeback is a **better** compliance answer than a standalone server with no patching and a default password.

> "Your grant requires NIST 800-171. Our platform meets it. Does your lab cluster?"

### Political Objection Cheat Sheet

| Objection | Response |
|---|---|
| "Central IT is slow" | This is self-service. Same day access. |
| "I need control" | You pick your config, you get admin on your environment. |
| "My dean won't fund someone else's infra" | Your dean funds nothing — your grant does, and only pays for what you use. |
| "I don't trust shared" | Your workloads are isolated, your data is segmented, here's the compliance cert. |
| "I just want to use AWS" | You can. But when the grant audit asks for your compliance documentation, access logs, and data management plan — who's filling that out? And when your student graduates, who's getting that data back? |

---

## Why "I'll Just Use AWS" Doesn't Work

Researchers say: "I'll just put it on AWS with my grant credit."

What actually happens:

**The bill explodes.** Grant gets $10k AWS credits, burns through them in 3 weeks running GPUs. No one set a budget alert. PI gets a $47k invoice, calls IT panicking.

**Compliance is their problem.** They spun up a default VPC, public S3 bucket, no encryption. Grant requires NIST 800-171 — they don't know what that means. University is liable, not AWS.

**The grad student leaves.** Account was in their personal email. Root credentials on a sticky note. 4TB of irreplaceable research data locked in an account nobody can access.

**No institutional visibility.** Finance can't reconcile spend against the grant. Security can't scan it. 15 different AWS accounts across campus, nobody knows they exist.

**Data egress costs.** Getting data OUT of AWS costs money. Researcher generates 20TB of results, wants to share with a collaborator. "$1,800 to download my own data??" Grant ends, they need to archive, egress eats remaining funds.

The platform doesn't compete with cloud. It makes cloud irrelevant for most research workloads by delivering the same outcome — ready now, compliant, managed — without the billing surprises, lock-in, or orphaned accounts.

---

## The Funding Model

The platform is self-sustaining. No annual budget ask. No capital campaign. Grants fund it.

```
Grant approved → PI allocates compute costs → Draws from shared pool
                                                ↓
                                          Usage charged to grant #
                                                ↓
                                          Funds flow back to pool
                                                ↓
                                          Pool grows → more capacity
```

### Seed Capacity

Those 100+ existing lab servers become your starting pool:

1. **Audit** what's out there — serial numbers, age, utilization, owner, grant
2. **Consolidate** — anything under 3-4 years old gets racked into the shared pool
3. **Decommission** — anything older gets retired (this alone reduces risk)
4. **Onramp** — PIs who had those boxes get equivalent capacity in the platform initially

### Ongoing Funding

| Cost | Funded by |
|---|---|
| Initial pool hardware | Consolidated existing boxes + institutional investment |
| Ongoing capacity growth | Grant chargebacks (CPU hours + storage) |
| Operations / staff | Overhead rate or service fee baked into chargeback |
| Hardware refresh cycle | Built into the per-unit rate — no surprise capital asks |

### Rate Card

Keep it simple. Researchers don't want to decode a pricing page.

- **Compute**: $/vCPU/month + $/GB RAM/month
- **Storage**: $/TB/month (standard), $/TB/month (research NFS)
- **That's it.** Network, backups, compliance, support — included.

See `chargeback/templates/rates.yml` for the configurable rate card.

---

## The Lifecycle Model

Every allocation has a date on it. When the grant ends:

1. **30-day notice** — migrate your data, renew, or archive
2. **Department can extend** — pay from departmental funds at the same rate
3. **Data archival** — cold storage option for research data retention requirements
4. **Resources return to pool** — automatically, no zombie servers

```
Grant active    → Full access, charged monthly
Grant ending    → 30-day notice, PI decides next step
Grant expired   → Read-only (data retention period)
Retention met   → Archive or delete, resources return to pool
```

No more "whose box is this and why is it on fire." No more lifetime support of infrastructure from a grant that ended 7 years ago. Departments can extend support on allocated resources, or the grant is tied to CPU hours and storage costs that have a defined expiration.

---

## The Consolidation Playbook

### Step 1: Discovery

Find out what's running across campus. Not to police — to understand.

- What workloads exist?
- What grants funded them?
- What's the hardware age and utilization?
- What compliance requirements apply?

### Step 2: Parity

Build catalog items that match the top 5 workloads researchers are already running. If 30% of those boxes are running MATLAB simulations, make sure the platform can do that on day one.

### Step 3: Sweetener

Add something they can't do alone:

- Burst capacity beyond what any single lab can afford
- Shared GPU pools
- Built-in backups, monitoring, compliance documentation
- Fast storage that a department budget can't justify

### Step 4: Pilot

Get one PI — ideally one starting a new grant — to use the platform. Make them wildly successful. Let them evangelize in the faculty hallway.

Word of mouth from a peer PI is worth more than any IT presentation.

### Step 5: Grow

As grants fund usage, the pool grows. As the pool grows, more capacity attracts more users. The flywheel turns.

---

## Who to Get on Your Side First

1. **Sponsored Programs / Research Office** — When they say "this is the preferred way to meet grant compliance," the politics dissolve. The PI fighting you is now fighting their own funding office.
2. **CIO** — Executive air cover and infrastructure alignment.
3. **One champion PI** — A real researcher with a real grant who gets a real win. Their story sells the platform.
4. **Grants office / Finance** — They want clean audit trails. You're giving them exactly that.

Do NOT start with:
- Deans (they'll protect departmental budgets)
- Department heads (they'll see this as losing control)
- IT committees (they'll debate for 18 months)

Start with value. Let adoption create the mandate.

---

## What You Need to Launch

You don't need a portal, a fancy dashboard, or a 6-month project. You need:

1. CIO + executive blessing
2. Inventory of existing shadow IT (age, location, owner, grant)
3. Research office partnership for the compliance story
4. One pilot PI starting a new grant
5. A simple rate card
6. This reference architecture deployed

Everything else grows from there.
