# Asset sources

- **tuna_side.png** — cropped/downscaled from "File:Yellowfin-transp.png"
  (https://commons.wikimedia.org/wiki/File:Yellowfin-transp.png), credited
  there as "SEFSC Pascagoula Laboratory; Collection of Brandi Noble,
  NOAA/NMFS/SEFSC". Dual-licensed CC BY 2.0 and public domain
  (`PD-USGov-NOAA`, a US government work). Used as the side-profile texture
  for the playable Tuna (`scripts/player/tuna_model.gd`), mirrored onto both
  flanks of a flat cutout mesh — a stakeholder (animal enthusiast) flagged
  that the original all-procedural-primitives model didn't read as a real
  tuna, and a photo reference was the fix. The original, uncropped photo
  carries an Adobe Stock watermark in some search results for this fish —
  that watermarked copy was never used; only this NOAA public-domain photo.
- **tiger_shark_side.png** — cutout from "File:Fish4258 - Flickr - NOAA
  Photo Library.jpg"
  (https://commons.wikimedia.org/wiki/File:Fish4258_-_Flickr_-_NOAA_Photo_Library.jpg),
  credited there as "SEFSC Pascagoula Laboratory; Collection of Brandi
  Noble, NOAA/NMFS/SEFSC" — the same source collection as tuna_side.png
  above. Dual-licensed CC BY 2.0 and public domain (`PD-USGov-NOAA`).
  Unlike the tuna photo, this one was never pre-extracted with an alpha
  channel by a Commons contributor — the original shows a juvenile tiger
  shark lying on a boat deck. The deck background was removed by manually
  tracing the body/fin silhouette as a polygon (checked point-by-point
  against pixel brightness samples, since the deck's blue-grey tone and
  the shark's grey flank color are close enough that automatic chroma-key
  and edge-detection flood fill both leaked badly), then supersampling the
  polygon mask 2x before downscaling for anti-aliased edges. Used as the
  side-profile texture for the hostile Tiger Shark
  (`scripts/enemies/tiger_shark_model.gd`), built with the same inflated
  photo-sheet + alpha-derived core technique as the playable Tuna.
- **velociraptor_side.png** — cropped/downscaled and horizontally flipped
  (to put the head on the left, matching the other two cutout textures)
  from "File:Velociraptor_TD.png"
  (https://commons.wikimedia.org/wiki/File:Velociraptor_TD.png), a digital
  restoration by TotalDino, licensed CC BY 4.0 — attribution required.
  Already had a clean pre-made alpha channel (no hand-tracing needed, unlike
  the Tiger Shark). Chosen over several other candidate Velociraptor
  restorations specifically for its standing pose with both legs planted
  directly under the body with no gap between leg and torso in the
  silhouette — the model-building technique in
  `scripts/player/velociraptor_model.gd` depends on each image column being
  a single contiguous opaque run.
