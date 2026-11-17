-- Initial schema for this new Netlify installation.
-- Subsequent schema changes must be added in new migration files.


-- Source: db/migrations/20260325160428_init.sql
create table if not exists public."user" (
  id text primary key,
  name text not null,
  email text not null unique,
  "emailVerified" boolean not null default false,
  image text,
  "createdAt" timestamptz not null default current_timestamp,
  "updatedAt" timestamptz not null default current_timestamp
);

create table if not exists public.session (
  id text primary key,
  "expiresAt" timestamptz not null,
  token text not null unique,
  "createdAt" timestamptz not null default current_timestamp,
  "updatedAt" timestamptz not null default current_timestamp,
  "ipAddress" text,
  "userAgent" text,
  "userId" text not null references public."user"(id) on delete cascade
);

create table if not exists public.account (
  id text primary key,
  "accountId" text not null,
  "providerId" text not null,
  "userId" text not null references public."user"(id) on delete cascade,
  "accessToken" text,
  "refreshToken" text,
  "idToken" text,
  "accessTokenExpiresAt" timestamptz,
  "refreshTokenExpiresAt" timestamptz,
  scope text,
  password text,
  "createdAt" timestamptz not null default current_timestamp,
  "updatedAt" timestamptz not null default current_timestamp
);

create table if not exists public.verification (
  id text primary key,
  identifier text not null,
  value text not null,
  "expiresAt" timestamptz not null,
  "createdAt" timestamptz not null default current_timestamp,
  "updatedAt" timestamptz not null default current_timestamp
);

create table if not exists public.envelopes (
  id text primary key,
  user_id text not null references public."user"(id) on delete cascade,
  title text not null,
  status text not null default 'draft'
    check (status in ('draft', 'sent', 'completed', 'declined', 'voided')),
  source_pdf_key text not null,
  source_pdf_filename text not null,
  source_pdf_size_bytes bigint not null check (source_pdf_size_bytes > 0),
  page_count integer not null check (page_count > 0),
  signed_pdf_key text,
  evidence_key text,
  source_pdf_hash text not null check (length(source_pdf_hash) = 64),
  sent_at bigint,
  completed_at bigint,
  declined_at bigint,
  voided_at bigint,
  created_at bigint not null default (extract(epoch from now())::bigint),
  updated_at bigint not null default (extract(epoch from now())::bigint)
);

create table if not exists public.envelope_pages (
  id text primary key,
  envelope_id text not null references public.envelopes(id) on delete cascade,
  page_number integer not null check (page_number > 0),
  width_pt real not null check (width_pt > 0),
  height_pt real not null check (height_pt > 0),
  unique (envelope_id, page_number)
);

create table if not exists public.signers (
  id text primary key,
  envelope_id text not null references public.envelopes(id) on delete cascade,
  name text not null,
  email text not null,
  sign_order integer not null check (sign_order > 0),
  status text not null default 'pending'
    check (status in ('pending', 'notified', 'signed', 'declined')),
  signing_token_hash text,
  signing_token_expires_at bigint,
  turn_started_at bigint,
  last_notified_at bigint,
  last_nudged_at bigint,
  signed_at bigint,
  declined_at bigint,
  decline_reason text,
  created_at bigint not null default (extract(epoch from now())::bigint),
  updated_at bigint not null default (extract(epoch from now())::bigint),
  constraint signers_id_envelope_unique unique (id, envelope_id),
  constraint signers_envelope_order_unique unique (envelope_id, sign_order)
);

create table if not exists public.recipient_download_tokens (
  token_hash text primary key check (length(token_hash) = 64),
  envelope_id text not null,
  signer_id text not null,
  file_type text not null check (file_type in ('signed', 'evidence')),
  expires_at bigint not null,
  created_at bigint not null default (extract(epoch from now())::bigint),
  constraint recipient_download_tokens_signer_envelope_fk
    foreign key (signer_id, envelope_id)
    references public.signers(id, envelope_id)
    on delete cascade,
  constraint recipient_download_tokens_signer_file_unique
    unique (envelope_id, signer_id, file_type),
  check (expires_at >= created_at)
);

create table if not exists public.fields (
  id text primary key,
  envelope_id text not null references public.envelopes(id) on delete cascade,
  signer_id text not null,
  type text not null
    check (type in ('signature', 'initials', 'date', 'text', 'checkbox')),
  page integer not null check (page > 0),
  x real not null check (x >= 0 and x <= 1),
  y real not null check (y >= 0 and y <= 1),
  width real not null check (width > 0 and width <= 1),
  height real not null check (height > 0 and height <= 1),
  required boolean not null default true,
  label text,
  input_method text
    check (input_method is null or input_method in ('typed', 'drawn', 'auto')),
  value text,
  image_key text,
  checked boolean,
  submitted_at bigint,
  created_at bigint not null default (extract(epoch from now())::bigint),
  updated_at bigint not null default (extract(epoch from now())::bigint),
  check (x + width <= 1.000001),
  check (y + height <= 1.000001),
  constraint fields_signer_envelope_fk
    foreign key (signer_id, envelope_id)
    references public.signers(id, envelope_id)
    on delete cascade
);

create table if not exists public.audit_events (
  id text primary key,
  envelope_id text not null references public.envelopes(id) on delete cascade,
  event text not null
    check (event in (
      'created',
      'sent',
      'viewed',
      'signed',
      'declined',
      'reminded_manual',
      'completed',
      'voided'
    )),
  actor_type text not null
    check (actor_type in ('sender', 'signer', 'system')),
  actor_email text,
  ip_address text,
  user_agent text,
  metadata jsonb,
  created_at bigint not null default (extract(epoch from now())::bigint)
);

create table if not exists public.account_closure_requests (
  user_id text primary key references public."user"(id) on delete cascade,
  requested_at bigint not null,
  export_expires_at bigint not null,
  purge_after_at bigint not null,
  updated_at bigint not null,
  check (export_expires_at >= requested_at),
  check (purge_after_at >= export_expires_at)
);

create index if not exists account_userid_idx
  on public.account ("userId");

create index if not exists session_userid_idx
  on public.session ("userId");

create index if not exists verification_identifier_idx
  on public.verification (identifier);

create index if not exists idx_envelopes_user_created_at
  on public.envelopes(user_id, created_at desc);

create index if not exists idx_envelopes_user_status
  on public.envelopes(user_id, status, created_at desc);

create unique index if not exists idx_signers_envelope_email
  on public.signers(envelope_id, lower(email));

create index if not exists idx_signers_envelope_status
  on public.signers(envelope_id, status);

create unique index if not exists idx_signers_signing_token_hash
  on public.signers(signing_token_hash)
  where signing_token_hash is not null;

create unique index if not exists idx_signers_single_notified
  on public.signers(envelope_id)
  where status = 'notified';

create index if not exists idx_recipient_download_tokens_expires_at
  on public.recipient_download_tokens(expires_at);

create index if not exists idx_fields_signer_envelope
  on public.fields(signer_id, envelope_id);

create index if not exists idx_fields_envelope_page
  on public.fields(envelope_id, page, created_at, id);

create index if not exists idx_audit_events_envelope_event
  on public.audit_events(envelope_id, event);

create index if not exists idx_audit_events_envelope_created_at
  on public.audit_events(envelope_id, created_at, id);

create index if not exists idx_audit_events_envelope_event_signer_id
  on public.audit_events(envelope_id, event, ((metadata->>'signerId')));

create index if not exists idx_account_closure_requests_purge_after
  on public.account_closure_requests(purge_after_at, requested_at);


-- Source: db/migrations/20261112060000_settings_and_roles.sql
-- Install-wide settings and the administrator role.
--
-- app_settings holds exactly one row (the boolean primary key can only be
-- true). It is written by the first-run setup page and by an administrator
-- in Settings. Until that row exists the app behaves as it did before this
-- migration: anyone can create an account, and email addresses come from
-- environment variables.

create table if not exists public.app_settings (
  id boolean primary key default true check (id),
  organization_name text,
  sender_address text,
  support_address text,
  signup_mode text not null default 'closed'
    check (signup_mode in ('closed', 'domains', 'open')),
  allowed_email_domains text[] not null default '{}',
  terms_url text,
  privacy_url text,
  -- Set once email has been seen working from the current sender address,
  -- and cleared whenever that address changes.
  email_ready_at bigint,
  setup_completed_at bigint,
  created_at bigint not null,
  updated_at bigint not null
);

alter table public."user"
  add column if not exists role text not null default 'user';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'user_role_check'
  ) then
    alter table public."user"
      add constraint user_role_check check (role in ('user', 'admin'));
  end if;
end
$$;

create index if not exists user_role_admin_idx
  on public."user" (role) where role = 'admin';


-- Source: db/migrations/20261112070000_rate_limits.sql
-- Rate limit counters.
--
-- One row per thing being limited (a hash of "which limit, for whom"), with
-- how many requests it has made in its current window and when that window
-- ends. Kept in Postgres because a deployment on Vercel runs as many
-- short-lived instances that share nothing else.

create table if not exists public.rate_limits (
  key text primary key,
  count integer not null,
  expires_at bigint not null
);

-- For clearing out windows that have ended.
create index if not exists rate_limits_expires_at_idx
  on public.rate_limits (expires_at);


-- Source: db/migrations/20261113090000_signature_evidence.sql
-- Evidence and record-keeping for signed documents.
--
-- * envelopes: the SHA-256 of each finished file, so a copy can be checked
--   against the original later, and when the owner was last warned that the
--   retention period is about to remove the envelope.
-- * seal_keys: the key this install seals finished PDFs with. The private
--   key is stored encrypted with a key derived from the auth secret.
-- * signers: optional extra checks before signing (an access code the sender
--   shares, a one-time code sent by email), and when the signer agreed to
--   use electronic records.
-- * audit_events: new event kinds, and a hash chain so that a changed or
--   removed row can be detected.
-- * app_settings: how long finished envelopes are kept.

alter table public.envelopes
  add column if not exists signed_pdf_sha256 text
    check (signed_pdf_sha256 is null or length(signed_pdf_sha256) = 64),
  add column if not exists evidence_sha256 text
    check (evidence_sha256 is null or length(evidence_sha256) = 64),
  add column if not exists recipient_evidence_sha256 text
    check (
      recipient_evidence_sha256 is null
      or length(recipient_evidence_sha256) = 64
    ),
  add column if not exists retention_warned_at bigint;

create index if not exists idx_envelopes_signed_pdf_sha256
  on public.envelopes(signed_pdf_sha256)
  where signed_pdf_sha256 is not null;

create index if not exists idx_envelopes_evidence_sha256
  on public.envelopes(evidence_sha256)
  where evidence_sha256 is not null;

create index if not exists idx_envelopes_recipient_evidence_sha256
  on public.envelopes(recipient_evidence_sha256)
  where recipient_evidence_sha256 is not null;

create table if not exists public.seal_keys (
  id text primary key,
  certificate_pem text not null,
  encrypted_private_key text not null,
  created_at bigint not null,
  retired_at bigint
);

create unique index if not exists idx_seal_keys_single_active
  on public.seal_keys ((true))
  where retired_at is null;

alter table public.signers
  add column if not exists access_code_hash text,
  add column if not exists require_email_code boolean not null default false,
  add column if not exists email_code_hash text,
  add column if not exists email_code_expires_at bigint,
  add column if not exists email_code_attempts integer not null default 0,
  add column if not exists email_code_sent_at bigint,
  add column if not exists consented_at bigint;

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided'
    ));

alter table public.audit_events
  add column if not exists sequence integer,
  add column if not exists prev_hash text,
  add column if not exists row_hash text;

create unique index if not exists idx_audit_events_envelope_sequence
  on public.audit_events(envelope_id, sequence)
  where sequence is not null;

alter table public.app_settings
  add column if not exists retention_days integer
    check (retention_days is null or retention_days >= 30);


-- Source: db/migrations/20261114090000_envelope_deadline.sql
-- A deadline for each envelope, chosen by the sender when it is sent.
--
-- * envelopes.expires_at: when the request stops being signable. Every
--   signing link of the envelope expires at this moment. Null on envelopes
--   sent before this migration, whose links keep their own seven-day life.
-- * envelopes.expiry_notified_at: set once the daily job has told the sender
--   that the deadline passed, so it tells them only once.
-- * audit_events: two new kinds, for a changed deadline and a passed one.

alter table public.envelopes
  add column if not exists expires_at bigint,
  add column if not exists expiry_notified_at bigint;

create index if not exists idx_envelopes_expiry_due
  on public.envelopes(expires_at)
  where status = 'sent'
    and expires_at is not null
    and expiry_notified_at is null;

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided',
      'deadline_changed',
      'expired'
    ));


-- Source: db/migrations/20261114100000_automatic_reminders.sql
-- Automatic reminders, chosen by the sender for each envelope.
--
-- * envelopes.reminder_interval_days: how many days the daily job waits
--   after the last invitation or reminder before it reminds the signer whose
--   turn it is. Null means no automatic reminders.
-- * audit_events: a new kind for a reminder the job sent.

alter table public.envelopes
  add column if not exists reminder_interval_days smallint;

alter table public.envelopes
  drop constraint if exists envelopes_reminder_interval_days_check;

alter table public.envelopes
  add constraint envelopes_reminder_interval_days_check
    check (reminder_interval_days is null or reminder_interval_days between 1 and 30);

create index if not exists idx_envelopes_reminders_on
  on public.envelopes(id)
  where status = 'sent' and reminder_interval_days is not null;

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided',
      'deadline_changed',
      'expired',
      'reminded_auto'
    ));


-- Source: db/migrations/20261114110000_copy_recipients.sql
-- People who receive a copy of the finished document without signing it.
--
-- They live in the signers table, marked by role, so that everything keyed
-- to a recipient already covers them: download links, the signer data
-- request tools and the retention period. A copy recipient is never part
-- of the signing order: it stays 'pending' and never holds a signing link.

alter table public.signers
  add column if not exists role text not null default 'signer';

alter table public.signers
  drop constraint if exists signers_role_check;

alter table public.signers
  add constraint signers_role_check check (role in ('signer', 'cc'));

alter table public.signers
  drop constraint if exists signers_copy_recipient_never_signs;

alter table public.signers
  add constraint signers_copy_recipient_never_signs
    check (
      role = 'signer'
      or (status = 'pending' and signing_token_hash is null)
    );


-- Source: db/migrations/20261114120000_branding.sql
-- An install's own logo and color.
--
-- The logo is small (512 KB at most) and there is exactly one, so it lives
-- in the settings row rather than in file storage: it is replaced and
-- removed in one statement, and nothing can be left behind. logo_hash is
-- the start of the image's SHA-256. The address the logo is served at
-- carries it, so that address can be cached for good and still changes
-- whenever the logo does. The color is stored as the administrator chose
-- it; the shades the pages use are worked out from it when a page is built.

alter table public.app_settings
  add column if not exists brand_color text,
  add column if not exists logo_content_type text,
  add column if not exists logo_data bytea,
  add column if not exists logo_hash text;

alter table public.app_settings
  drop constraint if exists app_settings_brand_color_check;

alter table public.app_settings
  add constraint app_settings_brand_color_check
    check (brand_color is null or brand_color ~ '^#[0-9a-f]{6}$');

alter table public.app_settings
  drop constraint if exists app_settings_logo_check;

alter table public.app_settings
  add constraint app_settings_logo_check
    check (
      (
        logo_data is null
        and logo_content_type is null
        and logo_hash is null
      )
      -- Each part is tested for null first: a check that comes out as
      -- "unknown" is not a failed check, and would let a half-set logo in.
      or (
        logo_data is not null
        and logo_content_type is not null
        and logo_hash is not null
        and logo_hash ~ '^[0-9a-f]{16}$'
        and logo_content_type in ('image/png', 'image/jpeg', 'image/webp')
        and octet_length(logo_data) between 1 and 524288
      )
    );


-- Source: db/migrations/20261114130000_more_field_types.sql
-- Three more kinds of field: a number, a dropdown and a radio button.
--
-- A dropdown carries its list of choices in `options`. Radio buttons are
-- placed one by one, each its own row, and the buttons that belong together
-- share a `group_id`; the signer picks one button in each group. The name
-- of a radio button is its `label`.

alter table public.fields
  drop constraint if exists fields_type_check;

alter table public.fields
  add constraint fields_type_check check (
    type in (
      'signature',
      'initials',
      'date',
      'text',
      'checkbox',
      'number',
      'dropdown',
      'radio'
    )
  );

alter table public.fields
  add column if not exists options jsonb,
  add column if not exists group_id text;

alter table public.fields
  drop constraint if exists fields_options_only_on_dropdowns;

alter table public.fields
  add constraint fields_options_only_on_dropdowns check (
    options is null
    or (type = 'dropdown' and jsonb_typeof(options) = 'array')
  );

alter table public.fields
  drop constraint if exists fields_group_only_on_radios;

alter table public.fields
  add constraint fields_group_only_on_radios check (
    (type = 'radio') = (group_id is not null)
  );

create index if not exists idx_fields_envelope_group
  on public.fields(envelope_id, group_id)
  where group_id is not null;


-- Source: db/migrations/20261114140000_templates.sql
-- Templates: a document, its fields and its signing order, kept so the same
-- thing can be sent again without setting it up again.
--
-- A template holds no one's name or address. Each place in the signing
-- order is a role with a label ("Client", "Landlord"), and the person who
-- fills it is named when the template is used.
--
-- Roles and fields are stored whole, as JSON, because they are only ever
-- read and written together. The application checks their contents with the
-- same rules it applies to the fields of an envelope.
--   roles:  [{ "id": "...", "name": "Client" }, ...] in signing order
--   fields: placed fields, each with "signerId" naming one of the roles

create table if not exists public.templates (
  id text primary key,
  user_id text not null references public."user"(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 160),
  source_pdf_key text not null,
  source_pdf_filename text not null,
  source_pdf_size_bytes bigint not null check (source_pdf_size_bytes > 0),
  page_count integer not null check (page_count > 0),
  roles jsonb not null,
  fields jsonb not null,
  created_at bigint not null default (extract(epoch from now())::bigint),
  updated_at bigint not null default (extract(epoch from now())::bigint),
  constraint templates_roles_check check (
    case
      when jsonb_typeof(roles) = 'array'
        then jsonb_array_length(roles) between 1 and 10
      else false
    end
  ),
  constraint templates_fields_check check (jsonb_typeof(fields) = 'array')
);

create index if not exists idx_templates_user_created_at
  on public.templates(user_id, created_at desc, id);


-- Source: db/migrations/20261114150000_handed_over_envelopes.sql
-- When an account is closed, its finished envelopes are handed to an
-- administrator, because they are the organization's records and not the
-- person's who is leaving.
--
-- This marks an envelope that was handed over, and when, so that it can be
-- told apart from the envelopes its keeper sent themselves. Someone who
-- stops being an administrator keeps their own envelopes, and the marked
-- ones move on to an administrator who stays.

alter table public.envelopes
  add column if not exists handed_over_at bigint;


-- Source: db/migrations/20261115090000_part11_mode.sql
-- Part 11 mode: the controls FDA 21 CFR Part 11 asks of a system that keeps
-- signed electronic records. Off unless an administrator turns it on.
--
-- * app_settings.part11_mode: the switch.
-- * user: whether an administrator has checked who the person is (11.100(b)),
--   and the lock that wrong passwords at signing put on the account (11.300).
-- * envelopes.part11: the envelope was sent while the mode was on, so its
--   signers sign with their accounts. Kept with the envelope, so turning the
--   mode off later does not change the rules an envelope went out under.
-- * signers: the account that must sign, and what the signature means
--   (11.50: approval, review, responsibility or authorship).
-- * audit_events: a new event kind for a wrong password at signing.
-- * system_audit_events: one hash chain for the changes that are not about a
--   single envelope (settings, roles, identity checks, locks), 11.10(e).

alter table public.app_settings
  add column if not exists part11_mode boolean not null default false;

alter table public."user"
  add column if not exists identity_verified_at bigint,
  add column if not exists identity_verified_by text,
  add column if not exists identity_verification_note text,
  add column if not exists signing_failed_attempts integer not null default 0,
  add column if not exists signing_locked_at bigint;

alter table public.envelopes
  add column if not exists part11 boolean not null default false;

alter table public.signers
  add column if not exists user_id text,
  add column if not exists signature_meaning text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'signers_signature_meaning_check'
  ) then
    alter table public.signers
      add constraint signers_signature_meaning_check
        check (
          signature_meaning is null
          or signature_meaning in ('approval', 'review', 'responsibility', 'authorship')
        );
  end if;
end
$$;

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided',
      'deadline_changed',
      'expired',
      'reminded_auto',
      'reauthentication_failed'
    ));

create table if not exists public.system_audit_events (
  id text primary key,
  sequence integer not null unique,
  event text not null,
  actor_user_id text,
  actor_email text,
  target_user_id text,
  ip_address text,
  user_agent text,
  metadata jsonb,
  created_at bigint not null,
  prev_hash text,
  row_hash text not null
);

create index if not exists idx_system_audit_events_created_at
  on public.system_audit_events (created_at desc);


-- Source: db/migrations/20261115100000_copied_audit_event.sql
-- A draft made by copying an earlier envelope records that it was copied,
-- so its timeline is not the same as a document that was just uploaded.

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided',
      'deadline_changed',
      'expired',
      'reminded_auto',
      'reauthentication_failed',
      'copied'
    ));


-- Source: db/migrations/20261116090000_signer_signatures.sql
-- Signatures in the signer's own name: advanced (AdES) and qualified (QES)
-- electronic signatures under eIDAS, made by a signing provider (eID Easy, or
-- a trust service provider with the Cloud Signature Consortium API).
--
-- * envelopes.signature_level: simple (SignuDoc's own signature, sealed by
--   the install), advanced or qualified. Chosen when the envelope is sent,
--   with the provider it was sent with.
-- * envelopes.revision_key / revision_sha256: the PDF as the last signer
--   signed it. Each signer adds a revision with their own signature on top,
--   so the signatures before stay valid.
-- * provider_signing_sessions: one signer's trip to the provider. What the
--   signer submitted, the signing link and the provider's working state are
--   kept encrypted (secret_data), and only until the signer is back.

alter table public.envelopes
  add column if not exists signature_level text not null default 'simple',
  add column if not exists signature_provider text,
  add column if not exists revision_key text,
  add column if not exists revision_sha256 text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'envelopes_signature_level_check'
  ) then
    alter table public.envelopes
      add constraint envelopes_signature_level_check
        check (
          signature_level in ('simple', 'advanced', 'qualified')
          and (signature_level = 'simple') = (signature_provider is null)
        );
  end if;
end
$$;

create table if not exists public.provider_signing_sessions (
  id text primary key,
  envelope_id text not null references public.envelopes (id) on delete cascade,
  signer_id text not null references public.signers (id) on delete cascade,
  provider text not null,
  level text not null check (level in ('advanced', 'qualified')),
  -- pending: at the provider; signing: back with a signature, being saved.
  state text not null default 'pending'
    check (state in ('pending', 'signing', 'completed', 'failed')),
  -- The revision this one is added to: null for the first signer.
  base_sha256 text,
  -- This signer's revision, prepared, then signed.
  revision_key text not null,
  -- SHA-256 (hex) of the bytes the signature covers.
  content_digest text not null,
  secret_data text not null,
  submitted_at bigint not null,
  created_at bigint not null,
  expires_at bigint not null,
  completed_at bigint
);

create index if not exists idx_provider_signing_sessions_signer
  on public.provider_signing_sessions (signer_id, state);

create index if not exists idx_provider_signing_sessions_envelope
  on public.provider_signing_sessions (envelope_id);


-- Source: db/migrations/20261116100000_signer_corrected.sql
-- Sender correction of a waiting signer's name or email after send.
-- A new audit event kind records the old and new values in the hash chain.
-- Keeps 'copied' (copy to a new draft, the migration before this one) in the list.

alter table public.audit_events
  drop constraint if exists audit_events_event_check;

alter table public.audit_events
  add constraint audit_events_event_check
    check (event in (
      'created',
      'sent',
      'viewed',
      'consented',
      'verified',
      'verification_failed',
      'signed',
      'declined',
      'reminded_manual',
      'email_sent',
      'completed',
      'voided',
      'deadline_changed',
      'expired',
      'reminded_auto',
      'reauthentication_failed',
      'copied',
      'signer_corrected'
    ));


-- Source: db/migrations/20261117090000_sign_in_security.sql
-- Sign-in security: two-step sign-in (an authenticator app, with backup
-- codes) and the administrator's switch that requires it of everyone.
--
-- * user."twoFactorEnabled" and the "twoFactor" table are Better Auth's
--   two-factor plugin. The secret and the backup codes are stored encrypted
--   with BETTER_AUTH_SECRET.
-- * app_settings.require_two_factor: nobody can use the app until they have
--   set up two-step sign-in. Off unless an administrator turns it on.

alter table public."user"
  add column if not exists "twoFactorEnabled" boolean not null default false;

create table if not exists public."twoFactor" (
  id text primary key,
  secret text not null,
  "backupCodes" text not null,
  "userId" text not null references public."user"(id) on delete cascade,
  verified boolean not null default true,
  "failedVerificationCount" integer not null default 0,
  "lockedUntil" timestamptz
);

create index if not exists "twoFactor_userId_idx"
  on public."twoFactor" ("userId");

create index if not exists "twoFactor_secret_idx"
  on public."twoFactor" (secret);

alter table public.app_settings
  add column if not exists require_two_factor boolean not null default false;


-- Source: db/migrations/20261117100000_session_controls.sql
-- Session controls: how long a signed-in session may sit unused, and how
-- long it may last at most, both set by an administrator.
--
-- * session.last_active_at: when the session was last used, in seconds,
--   written at most once a minute. Null until the first use after this
--   migration, which counts from when the session was created.
-- * app_settings.session_idle_minutes: minutes without use before a session
--   ends. Null means sessions do not end for being idle.
-- * app_settings.session_max_hours: hours after sign-in when a session ends
--   whatever happens. Null means Better Auth's 7 days.

alter table public.session
  add column if not exists last_active_at bigint;

alter table public.app_settings
  add column if not exists session_idle_minutes integer
    check (session_idle_minutes is null or session_idle_minutes between 5 and 1440),
  add column if not exists session_max_hours integer
    check (session_max_hours is null or session_max_hours between 1 and 168);


-- Source: db/migrations/20261118090000_name_field.sql
-- A name field: filled in with the signer's name when they sign, the way a
-- date field is filled in with the day. The signer does not type it.

alter table public.fields
  drop constraint if exists fields_type_check;

alter table public.fields
  add constraint fields_type_check check (
    type in (
      'signature',
      'initials',
      'date',
      'name',
      'text',
      'checkbox',
      'number',
      'dropdown',
      'radio'
    )
  );


CREATE TABLE IF NOT EXISTS public.signudoc_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());

INSERT INTO public.signudoc_migrations (version) VALUES
  ('20260325160428_init'),
  ('20261112060000_settings_and_roles'),
  ('20261112070000_rate_limits'),
  ('20261113090000_signature_evidence'),
  ('20261114090000_envelope_deadline'),
  ('20261114100000_automatic_reminders'),
  ('20261114110000_copy_recipients'),
  ('20261114120000_branding'),
  ('20261114130000_more_field_types'),
  ('20261114140000_templates'),
  ('20261114150000_handed_over_envelopes'),
  ('20261115090000_part11_mode'),
  ('20261115100000_copied_audit_event'),
  ('20261116090000_signer_signatures'),
  ('20261116100000_signer_corrected'),
  ('20261117090000_sign_in_security'),
  ('20261117100000_session_controls'),
  ('20261118090000_name_field')
ON CONFLICT DO NOTHING;
