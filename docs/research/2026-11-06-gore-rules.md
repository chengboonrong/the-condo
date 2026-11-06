# Gore: what GitHub and itch.io allow (read 2026-11-06)

All pages below were read on 2026-11-06. None shows a "last updated" date except where noted, so any of them may change
after that day. This note quotes the policy text. It is a reading of that text, not a ruling by either platform; both
say they decide case by case.

## What the game shows

The road shows the penanggal of Malay folklore as a severed flying head with its windpipe, lungs, heart, stomach and
intestines hanging below it, wet and dark, in a muted palette. In one ending she drops onto a man and a dark pool
spreads under him. There is no sexual content and no real person or named place. The models and the code are in the public
repository (`art/penanggal/`, `assets/models/penanggal.glb`, `scripts/road/her.gd`).

## Result

Nothing the game shows is forbidden outright on either platform, going by the written text. Nothing here needs the owner
to stop work. Two points are the owner's call at publish time.

| Platform | Reading | Why |
|---|---|---|
| GitHub (public repository) | Allowed with conditions. The stricter of the two. | The policy bans content that "gratuitously depicts or glorifies violence", but names "creative works" as a legitimate reason to post violent content and says "a clear warning or disclaimer can help". |
| itch.io (game page and browser build) | Allowed. | No written rule bans realistic gore. The rules that touch it are about adult content (sexual material), shock-value pages (delisting from browse and search) and unlawful content. |

The owner's two calls:

1. **GitHub's wording is broad.** "Gratuitously" is not defined, and the policy does not say whether violence against a
   fictional character counts. A cautious reading treats the man knocked down in one ending as covered. The route the
   policy itself gives is the creative-works exception with a warning, which the README now has.
2. **itch.io's "Has sensitive content" setting.** The written rule says a page "that has strong adult themes" "must be
   marked", and the Creator FAQ defines adult content as sexualised material. It does not say whether horror gore
   counts. Ticking the box is the cautious choice, but it hides the page from logged-out visitors and from anyone with
   adult content turned off. Leaving it off fits the written definition, and carries the risk that staff, if the page is
   reported, decide differently. This is not decided in this repository; `docs/itch-page.md` records it as open.

## GitHub

**Acceptable Use Policies, section 2, "User Safety"**
([GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies),
read 2026-11-06, no date shown). GitHub does not allow content that "gratuitously depicts or glorifies violence, including
violent images".

**Threats of Violence and Gratuitously Violent Content**
([policy page](https://docs.github.com/en/site-policy/acceptable-use-policies/github-threats-of-violence-and-gratuitously-violent-content),
read 2026-11-06, no date shown). This page decides the case. It bars posting "text, imagery, or audio content glorifying
or containing a graphic depiction of violence toward oneself, another individual, group, or animal", and then:

> "We do not allow violent content to be posted indiscriminately or in a way that is difficult for other users to avoid,
> such as a profile avatar or an issue comment. However, we understand there may be legitimate reasons to post violent
> content, such as for educational or documentary purposes, creative works, or depictions of historical events. In those
> cases, a clear warning or disclaimer can help users make an educated decision as to whether or not they want to engage
> with such content. Still, GitHub may decide to limit the visibility of such content to those who choose to opt in."

**Community Guidelines**
([GitHub Community Guidelines](https://docs.github.com/en/site-policy/github-terms/github-community-guidelines), read
2026-11-06, no date shown). Reports are investigated "on a case-by-case basis—considering context and the surrounding
facts". Content "posted in a way that lacks context or makes it easy for other users to unwittingly view" may be
moderated.

**Enforcement** (Acceptable Use Policies, section 11): "GitHub retains full discretion to take action in response to a
violation of these policies, including account suspension, account termination, or removal of content."

**Sexual content.** The
[Sexually Obscene Content policy](https://docs.github.com/en/site-policy/acceptable-use-policies/github-sexually-obscene-content)
(read 2026-11-06) covers pornographic and sexually exploitative material. The game has none.

### How that applies to the repository

- The game is a creative work with folklore context, which is the category the policy names, with a warning.
- The risk is placement, not existence. The policy objects to violence "difficult for other users to avoid", and its
  examples are an avatar and an issue comment. A README banner, social-preview image or avatar showing the head and
  entrails is the case the text warns against. A model file or script in a folder is not.
- GitHub's documentation says "GitHub can host and render 3D files with the .stl extension"
  ([Working with non-code files](https://docs.github.com/en/repositories/working-with-files/using-files/working-with-non-code-files),
  read 2026-11-06). The models here are `.glb` and `.blend`, which GitHub does not draw in the browser; they download.
  Images committed to the README are displayed.
- Nothing in the policies treats code that builds or animates gore as violent content. They speak of "text, imagery, or
  audio content".
- Game Off asks entrants to "Create a public repository" and push "before December 1 at 13:37 PST"
  ([Game Off 2026 on itch.io](https://itch.io/jam/game-off-2026), read 2026-11-06), so the repository is public by
  requirement.

### Conditions kept (GitHub)

1. The README opens with a content warning before any image. It is there (blood and gore, a figure that appears
   suddenly, sudden loud sounds, flickering lights).
2. No gore in the README, the repository social preview, an avatar, or issue and discussion posts. The README has no
   images. Keep it that way.
3. The README says the game is folklore horror, so the context sits next to the content.
4. The residual risk stays: GitHub "may decide to limit the visibility" and has "full discretion". No rule defines
   "gratuitously". The warning and the placement are the mitigation, not a guarantee.

No repository setting for marking mature content turned up in the pages above. That is an absence in those pages, not a
statement that none exists.

## itch.io

**Quality guidelines**
([Content creator quality guidelines](https://itch.io/docs/creators/quality-guidelines), read 2026-11-06 and again in
the check for `docs/itch-page.md` the same day; the page says "This document is continually updated" and shows no date):

> "Adult content must be labeled. If you have a project page that has strong adult themes, then it must be marked.
> Someone browsing itch.io will only see adult content if they've enabled it on their account settings. ... Additionally,
> avoid using explicit images as your cover image. You can enable on your project's edit page: Metadata » Classification."

> "Avoid using shock images, loud noises, flashing imagery, or obnoxious material. This one can be quite subjective, but
> if your project's premise is around shocking the viewer by showing potentially offensive images, flashing colors, loud
> or annoying noises, or other material that is designed to be obnoxious then we may delist from our browse and search
> pages."

The penalty named for shock images is removal from browse and search; the page stays reachable by its URL. For not
respecting the adult classification it is harsher: itch.io "may remove all of your pages from being indexed on our
discovery features, or permanently disable payments on your account". The page does not mention blood, gore, violence or
an age rating.

**Creator FAQ, "Is adult content allowed?"** ([Creator FAQ](https://itch.io/docs/creators/faq#is-adult-content-allowed),
read 2026-11-06, no date shown). This is where itch.io defines adult content, and the definition is sexual: it bars
"sexualized images or videos of real-life humans", content "glorifying sexual violence" and sexual depictions of minors,
and says "Fictional, illustrated, and rendered content is generally fine, assuming it's legal". Its list of prohibited
payment-processor themes is about sexual content sold through card networks. It does not describe the game. If the game
is ever sold, the payment processors' own policies apply; those were not read.

**Terms of Service, section 3**
([itch.io Terms of Service](https://itch.io/docs/legal/terms), read 2026-11-06; the page carries "Updated April 15 2023"
beside a payment link and no other date). It bars "unlawful, misleading, malicious, or discriminatory content" and
unlawful acts. It has no passage on violence or gore. It also says: "The posting of content or other actions that, in
the Company’s sole discretion, degrades the experience of others may result in account termination without prior
notice".

**Discovery of adult-marked pages** ([Getting indexed](https://itch.io/docs/creators/getting-indexed), read
2026-11-06): a page marked NSFW "will only appear to people who have NSFW browsing enabled", and people without accounts
default to NSFW off.

**AI disclosure** (quality guidelines): projects "contain[ing] materials produced by generative AI" are tagged in the
AI Disclosure section. The same page says projects "using self-contained algorithms without external large datasets
don't require an AI disclosure". `docs/itch-page.md` has the facts for the owner's answer.

### Page settings that apply

- **Metadata » Classification** is where the guidelines say adult content is marked.
- **"Has sensitive content"** is the setting itch.io staff name in their UK Online Safety Act post
  ([post by site admin leafo, 2025-07-27](https://itch.io/t/5133739/our-update-on-the-uk-online-safety-act), read
  2026-11-06): the UK restriction uses "a combination of the “Has sensitive content” setting and the use of specific
  tags: “porn,” “adult,” “hentai,” “erotic,” and “sex”". Staff "may apply an override". A gore-only game with the setting
  off and none of those tags is not touched by that rule as written. The page adds a "Geo Restrictions" tab under
  Distribute that shows whether a project is restricted in the UK.
- **Tags.** A "Gore" tag exists and has a browse page ([Top games tagged Gore](https://itch.io/games/tag-gore), read
  2026-11-06). The guidelines ask for accurate tags.
- **Age rating.** There is no age-rating setting and no blood-and-gore setting in itch.io's documentation. A 2018 post
  by the same admin says "itch.io currently doesn't have a proper content rating (or age rating) system. At the moment
  the only option we have is a NSFW toggle that's hidden away in the metadata tab"
  ([thread](https://itch.io/t/251186/lets-talk-about-a-contentage-rating-system-for-itchio), read 2026-11-06). The 2025
  staff post still refers to the same single "sensitive" setting.
- **Browser build.** The [HTML5 documentation](https://itch.io/docs/creators/html5) (read 2026-11-06) adds no content
  rules. The default is "Click to Play", so the browser build is judged by the page's rules.

### Conditions kept (itch.io)

1. A content warning at the top of the description: blood and gore, a figure that appears suddenly, sudden loud sounds
   and flickering lights. It is in `docs/itch-page.md`.
2. A non-graphic cover image and thumbnail. Gore stays out of every image on the page; the page teases only.
3. Tag accurately: horror, plus a "gore" tag the owner decides on. Never "porn", "adult", "hentai", "erotic" or "sex".
4. Decide, and record, whether to tick "Has sensitive content" (open: see above).
5. Tag generative-AI material in the AI Disclosure section only if there is any.

## Not confirmed

- Neither platform defines "gratuitously" or says whether fictional characters count as "human beings".
- No itch.io document says how a moderator would classify horror gore. The statements above come from the written
  rules, not from moderation practice.
- The logged-in itch.io edit page was not opened, so the on-screen wording of the "Has sensitive content" checkbox is not
  confirmed from itch.io itself.
- The PayPal, Stripe and Payoneer policies were not read.
