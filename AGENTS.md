<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

- Generate immutable editorial flashcard codes using a database sequence and trigger, never client-side, because concurrent creates must remain globally unique across sections.
- Keep XLSX parsing and editorial validation in the editorial module; confirm and process durable imports through authenticated transactional database functions, because retries must preserve per-row atomicity and existing content triggers.
- Validate proposed study SQL against an isolated PostgreSQL fixture before applying it; label fixture results separately from live integration because the fixture is not the production schema.
- Keep study contracts, authenticated functions and query options in the study module; database RPCs own session/version pinning and atomic assessment commits so UI retries cannot alter learning integrity.
- Keep live homologation fixtures uniquely marked and archive only their recorded IDs; controlled rollback failures must stay confined to synthetic records so real learning history and principal accounts remain untouched.
