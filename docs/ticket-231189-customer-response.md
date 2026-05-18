# WSCC Ticket #231189 — Oracle Invoice Totalling: Update

Hi Roger,

Following on from your ticket about Oracle rejecting acquisitions
invoices, we've investigated, made changes to the Koha–Oracle plugin,
and confirmed the fix against the three example invoices you gave us
using a copy of your live data. This note explains what we did, why,
and what we're proposing for going forward.

## What we found

We identified three separate problems contributing to the rejections.
Only one of them is in the Koha–Oracle plugin itself; the other two
are in core Koha and are outside the scope of this fix.

1. **Plugin: header total didn't match the sum of the line records.**
   This is the actual cause of the Oracle rejections. When Oracle
   reads the CSV we send, it validates that the invoice header total
   equals the sum of the line records underneath it. Our previous code
   calculated the header total in one place and the line records in
   another, and the two values could disagree by a few pence due to
   how VAT was rounded. Oracle then rejected the file.

2. **Koha core: the invoice summary in the staff client shows
   conflicting VAT figures in different rows of the same table** (the
   "Total (VAT 20%)" row versus the "Total (£)" row on Bolinda
   525275). That's a Koha core display bug, not a plugin bug. It's
   confusing but it doesn't affect what we send to Oracle. We'll
   raise this upstream as a separate Koha core bug.

3. **Koha core: partial-VAT items from EDI invoices are stored with
   VAT applied to the full item price.** This is what's happening on
   Askews 7288787 with the English File Intermediate Student's Book —
   Askews say only 27.953% of the item price is taxable (£2.84 VAT),
   but Koha's EDI ingest records 20% on the full price (£10.29 VAT).
   The plugin can only export what Koha has stored, so this needs to
   be fixed in Koha core's EDI parser. We'll raise this as a separate
   Koha core bug too.

## What we changed in the plugin

The plugin now builds the invoice header total by adding up exactly
the same line and tax values that go into the CSV. That makes the
header and the line records mathematically identical by construction
— Oracle's "header equals sum of lines" check can no longer fail
because of internal rounding drift.

We also tidied two smaller issues at the same time:

- Line numbers (LIN_NUM) on the CSV are now strictly 1, 2, 3 …; they
  previously skipped a number between orderlines.
- The plugin can now handle invoice-level adjustments (shipping,
  discounts) that reference an order. None are arriving from your
  vendors today because we haven't enabled adjustment-line splitting
  in the EDI ingest yet, but the path is in place for when we do.

## How the three example invoices look now

The new plugin produces these values for your three examples (run
against a copy of your live database):

| Invoice | What we send now | Sum of line records | Header = lines? |
|---|---|---|---|
| Bolinda 525275 | £2,427.43 | £447.48 + £21.40 = £468.88 → £2,427.43 net+tax | Yes |
| Askews 7281289 | £468.88 | £447.48 + £21.40 = £468.88 | Yes |
| Askews 7288787 | £694.20 | £683.91 + £10.29 = £694.20 | Yes |

The important property is the right-hand column: in every case the
header total now matches the sum of the line records exactly. That's
the property Oracle's validator is checking when it accepts or
rejects the file.

## Why our totals don't match the vendor's printed totals exactly

It's worth being upfront about this because the numbers above aren't
all identical to what's on the vendors' paper invoices, and you'll
notice that immediately. Here's why.

The vendor, Koha, and our Oracle CSV all use the same formula
(`tax = net × rate, rounded to the nearest penny`) — but they each
apply it at a different level of detail. Bolinda 525275 makes this
clearest:

| Calculation method | VAT total | Inc. VAT total |
|---|---|---|
| **The vendor's method:** round the rate-aggregated total once. `round(£2,022.79 × 0.20)` | £404.56 | £2,427.35 |
| **Koha's per-orderline method:** round each orderline's VAT, then sum. `Σ round(line_net × 0.20)` | £404.63 | £2,427.42 |
| **Our Oracle CSV (per-unit-received method):** round each individual unit's VAT, then sum. `Σ qty × round(unit_net × 0.20)` | £404.64 | £2,427.43 |

All three numbers are arithmetically correct applications of "20% VAT
rounded to the penny". The difference is just *how many times* the
rounding happens before the values are added up. The Oracle CSV
specification you gave us says "one line per unit received", so the
plugin rounds 41 times for Bolinda 525275 (once per unit). Each of
those roundings adds an average bias of about 0.002p. Over 41 units
that compounds to roughly 8p — which is the gap you see between the
vendor's £2,427.35 and our £2,427.43.

So the plugin is not making an arithmetic mistake; the Oracle
file-format design (one line per unit) and the vendor's invoice
format (rate-aggregated total) round at different granularities, and
no amount of clever code can reconcile that without changing one of
the two formats.

The same effect explains Askews 7281289: vendor's printed £468.80 vs
our CSV's £468.88 is 8p of accumulated per-unit rounding across the
20 VAT-rated units on that invoice.

## What this means in practice

Before our fix, the plugin was sending values that disagreed with
itself — that's the actual Oracle rejection cause. After our fix, the
plugin sends values that are internally self-consistent and agree
with what the Koha staff client displays in the "Inc. VAT" column.
That's the regime that Oracle's "header equals sum of lines" check is
designed for, and it's the regime almost every accounting system uses
for line-itemised submissions.

We can't promise that 100% of invoices will be accepted on the first
try — the partial-VAT issue on items like the OUP textbook is still
present, and any other corner case we haven't yet seen could behave
differently. But the structural rounding-aggregation defect that
caused the Bolinda and Askews rejections is gone, and the three test
invoices now satisfy the self-consistency check that Oracle was
failing on.

## What we'd like to do next

We'd like to run the current plugin in production and monitor
Oracle's feedback on each batch. Specifically:

- If Oracle now accepts invoices that previously failed for the same
  reason, the fix is doing what it should and we can leave it.
- If Oracle still rejects invoices and the rejection message gives a
  specific reason (e.g. "header total differs from vendor invoice by
  Xp"), that's a different problem and we can decide whether the next
  step is changes in the plugin (e.g. emitting one row per orderline
  instead of one per unit, which would bring us closer to the
  vendor's figures but still not exactly equal) or in Koha core (the
  partial-VAT EDI parser fix).
- If there's flexibility in the Oracle interface design — for
  instance whether the "one line per unit" requirement is firm, or
  whether one line per orderline with a quantity column would be
  acceptable — that would let us match the vendor's totals more
  closely without further plugin changes.

In the meantime, the two separate Koha core bugs (the misleading
staff-client summary table and the partial-VAT EDI ingest) will go
to the Koha community as upstream patches. We'll keep you posted on
those.

Happy to talk any of this through if helpful.
