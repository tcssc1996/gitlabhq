# frozen_string_literal: true

RSpec.shared_examples 'validation on Time arguments' do
  context 'when `to` parameter is higher than `from`' do
    let(:variables) do
      {
        path: full_path,
        from: 1.day.ago.iso8601,
        to: 2.days.ago.iso8601
      }
    end

    it 'returns error' do
      expect(result).to be_nil
      expect(graphql_errors.first['message']).to include('`from` argument must be before `to` argument')
    end
  end

  context 'when from and to parameter range is higher than 180 days' do
    let(:variables) do
      {
        path: full_path,
        from: Time.now,
        to: 181.days.from_now
      }
    end

    it 'returns error' do
      expect(result).to be_nil
      expect(graphql_errors.first['message']).to include('Max of 180 days timespan is allowed')
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics issueCount examples' do
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:author) { create(:user) }
  let_it_be(:assignee) { create(:user) }

  let_it_be(:issue1) { create(:issue, project: project1, author: author, created_at: 12.days.ago) }
  let_it_be(:issue2) { create(:issue, project: project2, author: author, created_at: 13.days.ago) }

  let_it_be(:issue3) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago)
  end

  let_it_be(:issue4) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      created_at: 15.days.ago)
  end

  let_it_be(:issue_outside_of_the_range) { create(:issue, project: project2, author: author, created_at: 50.days.ago) }

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            issueCount(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 20.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'issueCount')
  end

  it 'returns the correct count' do
    expect(result).to eq({
      'identifier' => 'issues',
      'unit' => nil,
      'value' => 4,
      'title' => n_('New Issue', 'New Issues', 4)
    })
  end

  context 'with partial filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to eq({
        'identifier' => 'issues',
        'unit' => nil,
        'value' => 2,
        'title' => n_('New Issue', 'New Issues', 2)
      })
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to eq({
        'identifier' => 'issues',
        'unit' => nil,
        'value' => 1,
        'title' => n_('New Issue', 'New Issues', 1)
      })
    end
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  it_behaves_like 'validation on Time arguments'
end

RSpec.shared_examples 'value stream analytics flow metrics deploymentCount examples' do
  let_it_be(:deployment1) do
    create(:deployment, :success, environment: production_environment1, finished_at: 5.days.ago)
  end

  let_it_be(:deployment2) do
    create(:deployment, :success, environment: production_environment2, finished_at: 10.days.ago)
  end

  let_it_be(:deployment3) do
    create(:deployment, :success, environment: production_environment2, finished_at: 15.days.ago)
  end

  let(:variables) do
    {
      path: full_path,
      from: 12.days.ago.iso8601,
      to: 3.days.ago.iso8601
    }
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            deploymentCount(from: $from, to: $to) {
              value
              unit
              identifier
              title
            }
          }
        }
      }
    QUERY
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'deploymentCount')
  end

  it 'returns the correct count' do
    expect(result).to eq({
      'identifier' => 'deploys',
      'unit' => nil,
      'value' => 2,
      'title' => n_('Deploy', 'Deploys', 2)
    })
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 20.days.ago.iso8601,
        to: 18.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to eq({
        'identifier' => 'deploys',
        'unit' => nil,
        'value' => 0,
        'title' => n_('Deploy', 'Deploys', 0)
      })
    end
  end

  it_behaves_like 'validation on Time arguments'
end

RSpec.shared_examples 'value stream analytics flow metrics leadTime examples' do
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:author) { create(:user) }
  let_it_be(:assignee) { create(:user) }

  let_it_be(:issue1) do
    create(:issue, project: project1, author: author, created_at: 17.days.ago, closed_at: 12.days.ago)
  end

  let_it_be(:issue2) do
    create(:issue, project: project2, author: author, created_at: 16.days.ago, closed_at: 13.days.ago)
  end

  let_it_be(:issue3) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago,
      closed_at: 11.days.ago)
  end

  let_it_be(:issue4) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      created_at: 20.days.ago,
      closed_at: 15.days.ago)
  end

  before do
    Analytics::CycleAnalytics::DataLoaderService.new(group: group, model: Issue).execute
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            leadTime(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'leadTime')
  end

  it 'returns the correct value' do
    expect(result).to match(a_hash_including({
      'identifier' => 'lead_time',
      'unit' => n_('day', 'days', 4),
      'value' => 4,
      'title' => _('Lead Time'),
      'links' => [
        { 'label' => s_('ValueStreamAnalytics|Dashboard'), 'url' => match(/issues_analytics/) },
        { 'label' => s_('ValueStreamAnalytics|Go to docs'), 'url' => match(/definitions/) }
      ]
    }))
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => nil }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 3 }))
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics cycleTime examples' do
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:author) { create(:user) }
  let_it_be(:assignee) { create(:user) }

  let_it_be(:issue1) do
    create(:issue, project: project1, author: author, closed_at: 12.days.ago).tap do |issue|
      issue.metrics.update!(first_mentioned_in_commit_at: 17.days.ago)
    end
  end

  let_it_be(:issue2) do
    create(:issue, project: project2, author: author, closed_at: 13.days.ago).tap do |issue|
      issue.metrics.update!(first_mentioned_in_commit_at: 16.days.ago)
    end
  end

  let_it_be(:issue3) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      closed_at: 11.days.ago).tap do |issue|
        issue.metrics.update!(first_mentioned_in_commit_at: 14.days.ago)
      end
  end

  let_it_be(:issue4) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      closed_at: 15.days.ago).tap do |issue|
        issue.metrics.update!(first_mentioned_in_commit_at: 20.days.ago)
      end
  end

  before do
    Analytics::CycleAnalytics::DataLoaderService.new(group: group, model: Issue).execute
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            cycleTime(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'cycleTime')
  end

  it 'returns the correct value' do
    expect(result).to eq({
      'identifier' => 'cycle_time',
      'unit' => n_('day', 'days', 4),
      'value' => 4,
      'title' => _('Cycle Time'),
      'links' => []
    })
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => nil }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 3 }))
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics issuesCompleted examples' do
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:author) { create(:user) }
  let_it_be(:assignee) { create(:user) }

  # we don't care about opened date, only closed date.
  let_it_be(:issue1) do
    create(:issue, project: project1, author: author, created_at: 17.days.ago, closed_at: 12.days.ago)
  end

  let_it_be(:issue2) do
    create(:issue, project: project2, author: author, created_at: 16.days.ago, closed_at: 13.days.ago)
  end

  let_it_be(:issue3) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago,
      closed_at: 11.days.ago)
  end

  let_it_be(:issue4) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      created_at: 20.days.ago,
      closed_at: 15.days.ago)
  end

  before do
    Analytics::CycleAnalytics::DataLoaderService.new(group: group, model: Issue).execute
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            issuesCompletedCount(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'issuesCompletedCount')
  end

  it 'returns the correct value' do
    expect(result).to match(a_hash_including({
      'identifier' => 'issues_completed',
      'unit' => n_('issue', 'issues', 4),
      'value' => 4,
      'title' => _('Issues Completed'),
      'links' => [
        { 'label' => s_('ValueStreamAnalytics|Dashboard'), 'url' => match(/issues_analytics/) },
        { 'label' => s_('ValueStreamAnalytics|Go to docs'), 'url' => match(/definitions/) }
      ]
    }))
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => 0.0 }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 1.0 }))
    end
  end
end
