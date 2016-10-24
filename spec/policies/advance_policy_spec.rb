require 'rails_helper'

RSpec.describe AdvancePolicy, :type => :policy do
  let(:user) { double(User, id: double('User ID'), member: nil) }
  let(:member) { double(Member, requires_dual_signers?: nil) }
  let(:advance_request) { double(AdvanceRequest) }

  describe '`show?` method' do
    subject { AdvancePolicy.new(user, :advance) }

    context 'for an intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(true) }

      it { should permit_action(:show) }
    end
    context 'for a non-intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(false) }

      context 'for a user associated with a member' do
        before { allow(user).to receive(:member).and_return(member) }

        context 'when the member requires dual signers' do
          before { allow(member).to receive(:requires_dual_signers?).and_return(true) }
          it { should_not permit_action(:show) }
        end

        context 'when the member does not require dual signers' do
          context 'for a signer' do
            before do
              allow(user).to receive(:roles).and_return([User::Roles::ADVANCE_SIGNER])
            end
            it { should permit_action(:show) }
          end

          context 'for a non-signer' do
            before do
              allow(user).to receive(:roles).and_return([])
            end
            it { should_not permit_action(:show) }
          end
        end
      end

      context 'for a user not associated with a member' do
        it { should_not permit_action(:show) }
      end
    end
  end

  describe '`execute?` method' do
    subject { AdvancePolicy.new(user, :advance) }

    context 'for an intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(true) }

      it { should_not permit_action(:execute) }
    end
    context 'for a non-intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(false) }

      context 'for a user associated with a member' do
        before { allow(user).to receive(:member).and_return(member) }

        context 'when the member requires dual signers' do
          before { allow(member).to receive(:requires_dual_signers?).and_return(true) }
          it { should_not permit_action(:execute) }
        end

        context 'when the member does not require dual signers' do
          context 'for a signer' do
            before do
              allow(user).to receive(:roles).and_return([User::Roles::ADVANCE_SIGNER])
            end
            it { should permit_action(:execute) }
          end

          context 'for a non-signer' do
            before do
              allow(user).to receive(:roles).and_return([])
            end
            it { should_not permit_action(:execute) }
          end
        end
      end

      context 'for a user not associated with a member' do
        it { should_not permit_action(:execute) }
      end
    end
  end

  describe '`modify?` method' do
    subject { AdvancePolicy.new(user, advance_request) }
    before do
      allow(advance_request).to receive(:owners).and_return(Set.new)
    end
    it 'returns true if the user is an owner of the advance' do
      advance_request.owners.add(user.id)
      expect(subject).to permit_action(:modify)
    end
    it 'returns false if the user is not an owner of the advance' do
      expect(subject).to_not permit_action(:modify)
    end
  end
end