---
stage: ModelOps
group: AI Assisted
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
type: index, reference
---

# Code Suggestions (Beta) **(FREE SAAS)**

> - [Introduced](https://about.gitlab.com/releases/2023/02/22/gitlab-15-9-released/#code-suggestions-available-in-closed-beta) in GitLab 15.9 as [Beta](/ee/policy/alpha-beta-support.md#beta) for early access Ultimate customers.
> - [Enabled](https://gitlab.com/gitlab-org/gitlab/-/issues/408104) as opt-in with GitLab 15.11 as [Beta](/ee/policy/alpha-beta-support.md#beta).
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/408158) from GitLab Ultimate to GitLab Premium in 16.0.
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/410801) from GitLab Premium to GitLab Free in 16.0.
> - [Enabled by default](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/121079) in GitLab 16.1.

WARNING:
This feature is in [Beta](/ee/policy/alpha-beta-support.md#beta).
Due to high demand, this feature may have unscheduled downtime and code suggestions in IDEs may be delayed.
Code Suggestions may produce [low-quality or incomplete suggestions](#model-accuracy-and-quality).
Beta users should read about the [known limitations](#known-limitations). We look forward to hearing your feedback.

Code Suggestions use generative AI to suggest code while you're developing.
Use Code Suggestions to write code more efficiently by viewing code suggestions
as you type. Depending on the cursor position, the extension either:

- Provides entire code snippets, like generating functions.
- Completes the current line.

To accept a suggestion, press <kbd>Tab</kbd>.

Code Suggestions are available in Visual Studio Code when you have the GitLab Workflow extension installed. [Additional IDE extension support](https://gitlab.com/groups/gitlab-org/-/epics/10542) is planned for the near future.

## Supported languages

Code Suggestions may produce [low-quality or incomplete suggestions](#model-accuracy-and-quality).

The best results from Code Suggestions are expected for these languages:

- C/C++
- C#
- Go
- Java
- JavaScript
- Python
- PHP
- Ruby
- Rust
- Scala
- TypeScript

Suggestions may be mixed for other languages. Using natural language code comments to request completions may also not function as expected.

Suggestions are best when writing new code. Editing existing functions or 'fill in the middle' of a function may not perform as expected.

We are making improvements to the Code Suggestions underlying AI model weekly to improve the quality of suggestions. Please remember that AI is non-deterministic, so you may not get the same suggestion week to week.

Usage of Code Suggestions is governed by the [GitLab Testing Agreement](https://about.gitlab.com/handbook/legal/testing-agreement/). Learn about [data usage when using Code Suggestions](#code-suggestions-data-usage).

## Enable Code Suggestions for an individual user

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/121079) in GitLab 16.1 as [Beta](/ee/policy/alpha-beta-support.md#beta).

Each user can enable Code Suggestions for themselves: 

1. On the top bar, in the upper-right corner, select your avatar.
1. On the left sidebar, select **Preferences**.
1. In the **Code Suggestions** section, enable the setting.

NOTE:
If Code Suggestions is [enabled for the group](../../group/manage.md#group-code-suggestions), the group setting overrides the user setting.

## Enable Code Suggestions in VS Code

Prerequisites:

- Your group owner must enable the [group level code suggestions setting](../../group/manage.md#group-code-suggestions).
- Code Suggestions must be [enabled for your user account](#enable-code-suggestions-for-an-individual-user).
- If using a [personal access token](../../profile/personal_access_tokens.md#create-a-personal-access-token), the token must have the `read_api` and `read_user` scopes.

To enable Code Suggestions in VS Code:

1. Download and configure the
   [GitLab Workflow extension](https://marketplace.visualstudio.com/items?itemName=GitLab.gitlab-workflow)
   for Visual Studio Code.
1. In **GitLab: Add Account to VS Code on Mac**, add your GitLab work account to the VS Code extension:
   - In macOS, press <kbd>Shift</kbd> + <kbd>Command</kbd> + <kbd>P</kbd>.
   - In Windows, press <kbd>Shift</kbd> + <kbd>Control</kbd> + <kbd>P</kbd>.
1. You can Authenticate with OAuth to GitLab.com or you can use a personal access token.

   1. To use OAuth (recommended):

      1. Type `GitLab: Authenticate with GitLab.com`. It appears as a quick action. Select it.
      1. Follow the alert links to open a GitLab authorization URL in your browser.
      1. In your browser, select the alert to open the URL with VS Code.

   1. To use a personal access token:

      1. Type `GitLab: Add Account to VS Code`. It appears as a quick action. Select it.
      1. Provide your GitLab instance URL. A default is provided.
      1. Provide your personal access token.
1. Regardless of the method you use to authenticate, after your GitLab account connects successfully, in the left sidebar, select **Extensions**.
1. Find the **GitLab workflow** extension, select **Settings** (**{settings}**), and select **Extension Settings**.
1. Enable **GitLab > AI Assisted Code Suggestions**.

Start typing and receive suggestions for your GitLab projects.

<div class="video-fallback">
  See an end-to-end demo: <a href="https://www.youtube.com/watch?v=WnxBYxN2-p4">Get started with GitLab Code Suggestions in VS Code</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube-nocookie.com/embed/WnxBYxN2-p4" frameborder="0" allowfullscreen> </iframe>
</figure>

## Stability and performance

This feature is currently in [Beta](/ee/policy/alpha-beta-support.md#beta).
While the Code Suggestions inference API operates completely within the GitLab.com enterprise infrastructure,
we expect a high demand for this Beta feature, which may cause degraded performance or unexpected downtime
of the feature. We have built this feature to gracefully degrade and have controls in place to allow us to
mitigate abuse or misuse. GitLab may disable this feature for any or all customers at any time at our discretion.

## Code Suggestions data usage

Code Suggestions is a generative artificial intelligence (AI) model hosted on GitLab.com.

Your personal access token enables a secure API connection to GitLab.com.
This API connection securely transmits a context window from VS Code to the Code Suggestions ML model for inference,
and the generated suggestion is transmitted back to VS Code.

### Data privacy

Code Suggestions operate completely in the GitLab.com infrastructure, providing the same level of
[security](https://about.gitlab.com/security/) as any other feature of GitLab.com, and processing any personal
data in accordance with our [Privacy Statement](https://about.gitlab.com/privacy/).

No new additional data is collected to enable this feature. The content of your GitLab hosted source code is
not used as training data. Source code inference against the Code Suggestions model is not used to re-train the model.
Your data also never leaves GitLab.com. All training and inference is done in GitLab.com infrastructure.

[Read more about the security of GitLab.com](https://about.gitlab.com/security/faq/).

### Training data

Code Suggestions uses open source pre-trained base models from the
[CodeGen family](https://openreview.net/forum?id=iaYcJKpY2B_) including CodeGen-MULTI and CodeGen-NL.
We then re-train and fine-tune these base models with a customized open source dataset to enable multi-language
support and additional use cases. This customized dataset contains non-preprocessed open source code in 13
programming languages from [The Pile](https://pile.eleuther.ai/) and the
[Google BigQuery source code dataset](https://cloud.google.com/blog/topics/public-datasets/github-on-bigquery-analyze-all-the-open-source-code).
We then process this raw dataset against heuristics that aim to increase the quality of the dataset.

The Code Suggestions model is not trained on GitLab customer data.

## Progressive enhancement

This feature is designed as a progressive enhancement to developers IDEs.
Code Suggestions offer a completion if the machine learning engine can generate a recommendation.
In the event of a connection issue or model inference failure, the feature gracefully degrades.
Code Suggestions do not prevent you from writing code in your IDE.

### Internet connectivity

Code Suggestions only work when you have internet connectivity and can access GitLab.com.
Code Suggestions are not available for self-managed customers, nor customers operating within an offline environment.

### Model accuracy and quality

While in Beta, Code Suggestions can generate low-quality, incomplete, and possibly insecure code.
We strongly encourage all beta users to leverage GitLab native
[Code Quality Scanning](../../../ci/testing/code_quality.md) and
[Security Scanning](../../application_security/index.md) capabilities.

GitLab uses a customized open source dataset to fine-tune the model to support multiple languages.
Based on the languages you code in, GitLab routes the request to a targeted inference and prompt engine
to get relevant suggestions.

GitLab is actively refining these models to:

- Improve the quality of recommendations.
- Add support for more languages.
- Add protections to limit personal data, insecure code, and other unwanted behavior
  that the model may have learned from training data.

## Known limitations

While in Beta, we are working on improving the accuracy of overall generated content.
However, Code Suggestions may generate suggestions that are:

- Low-quality
- Incomplete
- Produce failed pipelines
- Insecure code
- Offensive or insensitive

We are also aware of specific situations that can produce unexpected or incoherent results including:

- Suggestions written in the middle of existing functions, or "fill in the middle."
- Suggestions based on natural language code comments.
- Suggestions that mixed programming languages in unexpected ways.

## Feedback

Report issues in the [feedback issue](https://gitlab.com/gitlab-org/gitlab/-/issues/405152).
