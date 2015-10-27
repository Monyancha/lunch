class MembersController < ApplicationController
  skip_before_action :check_terms
  
  before_filter only: [:select_member, :set_member] do
    redirect_to after_sign_in_path_for(current_user) if current_member_id
    @members = MembersService.new(request).all_members
  end

  def select_member
    raise 'No members found!' unless @members.present?
    @members.collect! { |member| [member['name'], member['id']] }
    render layout: 'external'
  end

  def set_member
    member_id = params[:member_id].to_i
    member = @members.find { |member| member[:id] == member_id }
    raise 'invalid member ID!' unless member
    session['member_id'] = member_id
    session['member_name'] = member[:name]
    redirect_to after_sign_in_path_for(current_user)
  end

  def terms
    render layout: 'external'
  end

  # POST
  def accept_terms
    current_user.update_attribute(:terms_accepted_at, DateTime.now)
    current_user.reload
    redirect_to after_sign_in_path_for(current_user)
  end
end