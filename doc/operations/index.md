---
stage: Monitor
group: Respond
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Monitor application performance **(FREE)**

GitLab provides a variety of tools to help operate and maintain
your applications.

<!--- start_remove The following content will be removed on remove_date: '2023-08-22' -->

## Measure reliability and stability with metrics (removed)

This feature was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/346541) in GitLab 14.7
and [removed](https://gitlab.com/gitlab-org/gitlab/-/issues/399231) in 16.0.

<!--- end_remove -->

## Manage alerts and incidents

GitLab helps reduce alert fatigue for IT responders by providing tools to identify
issues across multiple systems and aggregate alerts in a centralized place. Your
team needs a single, central interface where they can investigate alerts
and promote the critical alerts to incidents.

Are your alerts too noisy? Alerts can be configured
and fine-tuned in GitLab immediately following a fire-fight.

- [Manage alerts and incidents](incident_management/index.md) in GitLab.
- Create a [status page](incident_management/status_page.md)
  to communicate efficiently to your users during an incident.

## Track errors in your application

GitLab integrates with [Sentry](https://sentry.io/welcome/) to aggregate errors
from your application and surface them in the GitLab UI with the sorting and filtering
features you need to help identify which errors are the most critical. Through the
entire triage process, your users can create GitLab issues to track critical errors
and the work required to fix them - all without leaving GitLab.

- Discover and view errors generated by your applications with
  [Error Tracking](error_tracking.md).

## Manage your infrastructure in code

GitLab stores and executes your infrastructure as code, whether it's
defined in Ansible, Puppet or Chef. We also offer native integration with
[Terraform](https://www.terraform.io/), uniting your GitOps and
Infrastructure-as-Code (IaC) workflows with the GitLab authentication, authorization,
and user interface. By lowering the barrier to entry for adopting Terraform, you
can manage and provision infrastructure through machine-readable definition files,
rather than physical hardware configuration or interactive configuration tools.
Definitions are stored in version control, extending proven coding techniques to
your infrastructure, and blurring the line between what is an application and what is
an environment.

- Learn how to [manage your infrastructure with GitLab and Terraform](../user/infrastructure/index.md).

## More features

- Deploy to different [environments](../ci/environments/index.md).
- Connect your project to a [Kubernetes cluster](../user/infrastructure/clusters/index.md).
- Create, toggle, and remove [feature flags](feature_flags.md).
