# FindMyEvent — Domain Glossary

Canonical language for this project. If a word is used in code, docs, or conversation, it means what this file says. Update this file when a term changes meaning — nowhere else.

## Terms

- **Region** — a supported city. Launch region: Skopje. The app shows one Region at a time.
- **Place** — a fixed physical location with coordinates: a club, a shop, a kiosk, a hookah bar. Places persist; they do not expire. A Place may have **Opening Hours**.
- **Event** — a time-bound happening (party, concert, stand-up night). An Event has a start time, an optional end time, and a location — usually a Place, sometimes ad-hoc coordinates (open-air party). Events expire after they end.
- **Category** — a label from the fixed taxonomy (e.g. `party`, `concert`, `cigarettes`, `alcohol`, `hookah`). Every Event and Place has exactly one primary Category. The taxonomy is curated by the team, not user-generated.
- **Filter** — a user's on-map selection of one or more Categories. Filters control which Pins render. No Filter selected = all Pins shown.
- **Pin** — the map marker representing one Event or one Place inside the current Region.
- **Open Now** — a Place state derived from its Opening Hours and current time. Only meaningful for Places, never Events (Events use start/end time instead).
- **Time Scope** — the time window the map shows Events for. Three granularities: **Daily** (one Event Night, default tonight; user switches between nights), **Monthly** (a whole month), and **Yearly/Ongoing** (long-running Events spanning the year, e.g. a season-long festival). The selected Time Scope filters which Events appear; an Event's own duration and dates are shown in its detail view, not on the pin.
- **Event Night** — the night an Event culturally belongs to. A night runs from 06:00 to 06:00 the next morning: a party starting Saturday 01:00 belongs to Friday's Event Night. All "which day" selection, grouping, and expiry reasons about Event Nights, never raw calendar dates.
- **Happening Now** — an Event whose start has passed but whose Event Night hasn't ended (explicit end time, or 06:00 fallback). Still on the map, visually marked; never hidden at start time.
- **Vice** — informal grouping word for legal-vice Categories (cigarettes, alcohol, hookah, betting). Marketing/product word only; the data model knows only Categories.
- **Curator** — a team member (currently David + friend) who approves submitted Events, maintains Places, and can enter Events directly. Every Event is visible only after Curator approval.
- **Organizer** — an external user with an account who submits their own Events for Curator approval. Exists from MVP.
- **Source** — an external site the scraper pulls Events from (e.g. a local ticket site, a venue's public page). Scraped Events enter the same approval queue as Organizer submissions. A Source has a trust level; Events from an **unverified** Source display a user-discretion notice.
- **User** — a registered regular account (not Organizer, not Curator). Users can browse like anyone (browsing needs no account) and leave Reviews.
- **Review** — a rating with optional text left by a User on a Place. Events are not reviewable (for now).
