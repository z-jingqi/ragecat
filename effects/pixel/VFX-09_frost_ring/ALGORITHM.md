# Circular frost pulse algorithm

All sampling is local to one ColorRect. UV coordinates map into an integer art grid
centered on the effect node. Sampling a cell center and assigning one discrete
color makes the texture-free result nearest-stable under integer display scaling.
The pixel's farthest corner, not merely its center, must fit inside the caller's
radius. Thus a bright square cannot suggest a hit outside the actual circle.

The circular head moves from a compact inner radius to the exact caller radius
with a quadratic ease-out over the expansion phase. The peak is briefly held,
then angular segments narrow independently and retreat. The clean outer edge is
pale; the band body is cyan; the wider asymmetric inward facets and cleavage marks
are blue. Sector variation is deterministic and fixed over the life of the pulse,
so it does not look like per-frame noise. There is no elliptical ground projection:
the underlying game's damage footprint is a circle.

At most 24 tiny diamonds follow inward-offset radial paths behind the passing
rim. They cool and shrink independently; they never form an outward particle cloud
beyond damage range. The final pixels disappear with the original band, with no
persistent decal or frost shell. This is immediate-hit feedback, not a warning or
an authoritative expanding collision wave.

One CPU-owned age uniform controls every stage. No shader TIME, wall clock,
process callback or automatic animation runs. Repeating an age/seed produces the
same geometry. Each instance has its own ShaderMaterial and one ColorRect, and
reuse updates those objects instead of creating accumulated particles. At expiry
the visual is hidden; the caller decides pooling or disposal. Work is one bounded
quad plus at most 24 analytical fleck checks per shaded pixel. Large radii cost more
fill rate and should be profiled in the target scene; the 4096-unit input limit is
not a performance guarantee.
