---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Application secrets

This page is a development guide for application secrets.

## Secret entries

|Entry                             |Description                                                        |
|---                               |---                                                                |
|`secret_key_base`                 | The base key to be used for generating a various secrets          |
| `otp_key_base`                   | The base key for One Time Passwords, described in [User management](../raketasks/user_management.md#rotate-two-factor-authentication-encryption-key)              |
|`db_key_base`                     | The base key to encrypt the data for `attr_encrypted` columns     |
|`openid_connect_signing_key`      | The signing key for OpenID Connect                                |
| `encrypted_settings_key_base`    | The base key to encrypt settings files with                       |
| `ci_jwt_signing_key`             | The base key for encrypting the `CI_JOB_JWT` and `CI_JOB_JWT_V2` predefined CI/CD variables. `CI_JOB_JWT` and `CI_JOB_JWT_V2` were [deprecated in GitLab 15.9](../update/deprecations.md#old-versions-of-json-web-tokens-are-deprecated) and are scheduled to be removed in GitLab 16.5. |

## Where the secrets are stored

|Installation type                  |Location                                                          |
|---                                |---                                                               |
|Omnibus                            |[`/etc/gitlab/gitlab-secrets.json`](https://docs.gitlab.com/omnibus/settings/backups.html#backup-and-restore-omnibus-gitlab-configuration)                                 |
|Cloud Native GitLab Charts         |[Kubernetes Secrets](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/f65c3d37fc8cf09a7987544680413552fb666aac/doc/installation/secrets.md#gitlab-rails-secret)|
|Source                             |`<path-to-gitlab-rails>/config/secrets.yml` (Automatically generated by [01_secret_token.rb](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/initializers/01_secret_token.rb))                       |

## Warning: Before you add a new secret to application secrets

Before you add a new secret to [`config/initializers/01_secret_token.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/initializers/01_secret_token.rb),
make sure you also update Omnibus GitLab or updates fail. Omnibus is responsible for writing the `secrets.yml` file.
If Omnibus doesn't know about a secret, Rails attempts to write to the file, but this fails because Rails doesn't have write access.
The same rules apply to Cloud Native GitLab charts, you must update the charts at first.
In case you need the secret to have same value on each node (which is usually the case) you need to make sure it's configured for all
GitLab.com environments prior to changing this file.

**Examples**

- [Change for source installation](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/27581)
- [Change for omnibus installation](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/3267)
- [Change for omnibus installation](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/4158)
- [Change for Cloud Native installation](https://gitlab.com/gitlab-org/charts/gitlab/-/merge_requests/1318)

## Further iteration

We may either deprecate or remove this automatic secret generation `01_secret_token.rb` in the future.
Please see [issue 222690](https://gitlab.com/gitlab-org/gitlab/-/issues/222690) for more information.
