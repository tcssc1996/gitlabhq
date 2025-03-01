# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NavHelper, feature_category: :navigation do
  describe '#header_links' do
    include_context 'custom session'

    before do
      allow(helper).to receive(:session).and_return(session)
    end

    context 'when the user is logged in' do
      let(:user) { create(:user) }
      let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(user) }

      before do
        allow(helper).to receive(:current_user).and_return(user)
        allow(helper).to receive(:current_user_mode).and_return(current_user_mode)
        allow(helper).to receive(:can?) { true }
      end

      it 'has all the expected links by default' do
        menu_items = [:user_dropdown, :search, :issues, :merge_requests, :todos]

        expect(helper.header_links).to contain_exactly(*menu_items)
      end

      it 'contains the impersonation link while impersonating' do
        expect(helper).to receive(:session) { { impersonator_id: 1 } }

        expect(helper.header_links).to include(:admin_impersonation)
      end

      context 'as admin' do
        let(:user) { create(:user, :admin) }

        context 'application setting :admin_mode is enabled' do
          it 'does not contain the admin mode link by default' do
            expect(helper.header_links).not_to include(:admin_mode)
          end

          context 'with admin mode enabled' do
            before do
              current_user_mode.request_admin_mode!
              current_user_mode.enable_admin_mode!(password: user.password)
            end

            it 'contains the admin mode link' do
              expect(helper.header_links).to include(:admin_mode)
            end
          end
        end

        context 'application setting :admin_mode is disabled' do
          before do
            stub_application_setting(admin_mode: false)
          end

          it 'does not contain the admin mode link' do
            expect(helper.header_links).not_to include(:admin_mode)
          end

          context 'with admin mode enabled' do
            before do
              current_user_mode.request_admin_mode!
              current_user_mode.enable_admin_mode!(password: user.password)
            end

            it 'has no effect on header links' do
              expect(helper.header_links).not_to include(:admin_mode)
            end
          end
        end
      end

      context 'when the user cannot read cross project' do
        before do
          allow(helper).to receive(:can?).with(user, :read_cross_project) { false }
        end

        it 'does not contain cross project elements when the user cannot read cross project' do
          expect(helper.header_links).not_to include(:issues, :merge_requests, :todos, :search)
        end

        it 'shows the search box when the user cannot read cross project and they are visiting a project' do
          helper.instance_variable_set(:@project, create(:project))

          expect(helper.header_links).to include(:search)
        end
      end
    end

    context 'when the user is not logged in' do
      let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(nil) }

      before do
        allow(helper).to receive(:current_user).and_return(nil)
        allow(helper).to receive(:current_user_mode).and_return(current_user_mode)
        allow(helper).to receive(:can?).with(nil, :read_cross_project) { true }
      end

      it 'returns only the sign in and search when the user is not logged in' do
        expect(helper.header_links).to contain_exactly(:sign_in, :search)
      end
    end
  end

  describe '.admin_monitoring_nav_links' do
    subject { helper.admin_monitoring_nav_links }

    it { is_expected.to all(be_a(String)) }
  end

  describe '#page_has_markdown?' do
    using RSpec::Parameterized::TableSyntax

    where path: %w(
      projects/merge_requests#show
      projects/merge_requests/conflicts#show
      issues#show
      milestones#show
      issues#designs
    )

    with_them do
      before do
        allow(helper).to receive(:current_path?).and_call_original
        allow(helper).to receive(:current_path?).with(path).and_return(true)
      end

      subject { helper.page_has_markdown? }

      it { is_expected.to eq(true) }
    end
  end

  describe '#show_super_sidebar?' do
    shared_examples 'show_super_sidebar is supposed to' do
      before do
        stub_feature_flags(super_sidebar_nav: new_nav_ff)
        user.update!(use_new_navigation: user_preference)
      end

      context 'with feature flag off' do
        let(:new_nav_ff) { false }

        context 'when user has new nav disabled' do
          let(:user_preference) { false }

          specify { expect(subject).to eq false }
        end

        context 'when user has new nav enabled' do
          let(:user_preference) { true }

          specify { expect(subject).to eq false }
        end
      end

      context 'with feature flag on' do
        let(:new_nav_ff) { true }

        context 'when user has not interacted with the new nav toggle yet' do
          let(:user_preference) { nil }

          specify { expect(subject).to eq false }

          context 'when the user was enrolled into the new nav via a special feature flag' do
            before do
              # this ff is disabled in globally to keep tests of the old nav working
              stub_feature_flags(super_sidebar_nav_enrolled: true)
            end

            specify { expect(subject).to eq true }
          end
        end

        context 'when user has new nav disabled' do
          let(:user_preference) { false }

          specify { expect(subject).to eq false }
        end

        context 'when user has new nav enabled' do
          let(:user_preference) { true }

          specify { expect(subject).to eq true }
        end
      end
    end

    context 'when nil is provided' do
      specify { expect(helper.show_super_sidebar?(nil)).to eq false }
    end

    context 'when no user is signed-in' do
      specify do
        allow(helper).to receive(:current_user).and_return(nil)

        expect(helper.show_super_sidebar?).to eq false
      end
    end

    context 'when user is signed-in' do
      let_it_be(:user) { create(:user) }

      context 'with current_user as a default' do
        before do
          allow(helper).to receive(:current_user).and_return(user)
        end

        subject { helper.show_super_sidebar? }

        it_behaves_like 'show_super_sidebar is supposed to'
      end

      context 'with user provided as an argument' do
        subject { helper.show_super_sidebar?(user) }

        it_behaves_like 'show_super_sidebar is supposed to'
      end
    end
  end
end
