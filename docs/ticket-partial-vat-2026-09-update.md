# WSCC — Partial-VAT EDI Invoices: Update (September 2026)

Hi Roger,

Thanks for sending over the two new examples (7308488 and 7318985) —
they've let us pin the cause down precisely.

## What we found

This is the same underlying issue we discussed back in May (ticket
#231189): Koha's EDI import doesn't read the VAT amount your suppliers
actually state on an invoice line. Instead it recalculates VAT itself,
assuming the *entire* line is taxed at one flat rate. That's fine for
a normal single-rate item, but it's wrong whenever a line is genuinely
mixed — part of its value taxable at the standard rate, part at zero.

Both of your new invoices turn out to involve the *same* title, and
that title is exactly this kind of mixed-rate item. Here's what the
supplier's own invoice data says versus what Koha recorded:

| Invoice | Supplier's actual VAT | Koha's recalculated VAT |
|---|---|---|
| 7308488 | £2.95 | £11.29 |
| 7318985 | £1.47 | £5.57 |
| **Total** | **£4.42** | **£16.86** |

£4.42 is exactly the VAT total you told us to expect, and £16.86 is
exactly the total that went to Oracle. Koha applied the standard 20%
rate to the item's whole value instead of only the portion your
supplier actually charges VAT on — which is why the numbers were
roughly four times too high.

## Why we're not patching Koha itself for this

We did look at fixing this directly in Koha's EDI import. The problem
is that the field Koha uses to store an item's VAT rate can only hold
one flat rate per line — there's no way to record "20% on part of
this, 0% on the rest." Worse, whenever anyone opens the ordinary
"receive shipment" screen and touches that line again (even just to
correct something unrelated), Koha recalculates the VAT from that
single flat rate and would silently overwrite any fix we made. So a
quick core patch would only be reliable until the next time the line
was touched — not something we're willing to ship as "fixed."

The good news is that a much more thorough rework of how Koha handles
acquisitions costing is already underway in the wider Koha community,
which will allow exactly this kind of split-rate line to be recorded
properly. We're raising this issue formally with that community now,
so it's on record and considered as part of that work, rather than
attempting a stopgap in the current data model that could quietly
break again (tracked as Koha community Bug 43510, if you'd like to
follow it).

## What we're doing for WSCC in the meantime

We're extending your WSCC Oracle export plugin to read the supplier's
true VAT figures directly from the original EDI file for lines like
this, and to add a clearly labelled adjustment to the affected invoice
so:

- the invoice **total** shown in Koha (and what's sent to Oracle)
  reflects the supplier's real figures, and
- the adjustment itself is visible on the invoice screen with a note
  explaining exactly why it's there (which order line, supplier's
  figure vs. Koha's original figure) — nothing is corrected silently.

One honest caveat: the *individual order line* in Koha's acquisitions
screens may still show the inflated per-line VAT figure until the
wider Koha rework lands — it's the invoice total and the Oracle export
that we're correcting now. We didn't want to quietly patch the
per-line figure given the overwrite risk described above.

We're building and testing this now against your two example
invoices and will confirm once it's deployed. If you come across any
further examples in the meantime, they're genuinely useful — the more
data points, the more confident we can be that the plugin handles
every shape of mixed-rate invoice your suppliers send.

Thanks again for your patience with this one.
