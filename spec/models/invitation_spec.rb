require 'spec_helper'

describe Invitation do
  let(:event) { Fabricate(:event) }
  let(:invitee) { Fabricate(:member) }
  let!(:hosting) { Fabricate(:hosting, sponsorable: event) }
  let(:invitation) { Fabricate(:invitation, invitable: event) }

  it { is_expected.to callback(:generate_token).before(:create) }
  it { is_expected.to callback(:send_invitation).after(:create) }
  it { is_expected.to callback(:give_away_spot).after(:update) }
  it { is_expected.to callback(:send_confirmation).after(:update) }

  context "scopes" do

    let!(:attending) { Fabricate(:accepted_invitation, invitable: event) }
    let!(:no_response) { Fabricate(:invitation, invitable: event) }
    let!(:waiting_list) { Fabricate(:waiting_invitation, invitable: event) }

    it "#accepted" do
      expect(event.invitations.accepted).to eq([attending])
    end

    it "#pending_response" do
      expect(event.invitations.pending_response).to eq([no_response])
    end

  end

  context "hooks" do
    it "#after_create" do
      expect_any_instance_of(Invitation).to receive(:send_invitation)

      Invitation.create! invitee: invitee, invitable: event
    end

    context "#after_update" do
      let(:invitation) { Fabricate(:invitation, invitable: event, attending: true) }

      context "attendance is false" do
        it "processess the waiting list" do
          other_invitation = Fabricate(:invitation, invitable: event, waiting_list: true)
          expect(invitation.invitable).to receive(:process_waiting_list)

          invitation.update_attribute(:attending, false)
        end
      end

      context "attendance is true and waiting_list is false" do
        let(:invitation) { Fabricate(:invitation, invitable: event, waiting_list: true) }

        it "sends a confirmation email" do
          expect(invitation).to receive(:send_confirmation)

          invitation.update_attributes(attending: true, waiting_list: false)
        end
      end
    end
  end

  context "methods" do
    it "#send_invitation" do
      expect(invitation.invitable).to receive(:email).with(:invite, invitation.invitee, invitation)

      invitation.send_invitation
    end

    it "#send_attendance_confirmation" do
      expect(invitation.invitable).to receive(:email).with(:confirm_attendance, invitation.invitee, invitation)

      invitation.send_confirmation
    end

    it "#send_reminder" do
      expect(invitation.invitable).to receive(:email).with(:invitation_reminder, invitation.invitee, invitation)

      invitation.send_reminder
    end
  end
end
