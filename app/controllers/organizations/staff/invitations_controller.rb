class Organizations::Staff::InvitationsController < Devise::InvitationsController
  include OrganizationScopable

  layout "dashboard", only: [:new, :create]

  before_action :configure_permitted_parameters, if: :devise_controller?

  # This action is for generally creating any User, and it is currently unused.
  # See the other sub InvitationsControllers for the used `new` actions.
  def new
    raise NotImplementedError, "Do not use the 'new' action in Staff::InvitationsController."
  end

  def create
    # We have different return paths based on the roles provided in the params.
    # If you extend this, make sure new paths have their own authz!
    case user_params[:roles]
    when "super_admin", "admin"
      authorize! User, context: {organization: Current.organization},
        with: Organizations::StaffInvitationPolicy

      @user = User.new(
        user_params.merge(password: SecureRandom.hex(8)).except(:roles)
      )
      @user.add_role(user_params[:roles], Current.organization)

      if @user.save
        @user.invite!(current_user)
        redirect_to staff_staff_index_path, notice: t(".success")
      else
        render "organizations/staff/staff_invitations/new", status: :unprocessable_entity
      end
    when "fosterer"
      authorize! User, context: {organization: Current.organization},
        with: Organizations::FostererInvitationPolicy

      @user = User.new(
        user_params.merge(password: SecureRandom.hex(8)).except(:roles)
      )
      @user.add_role("adopter", Current.organization)
      @user.add_role("fosterer", Current.organization)

      assign_person_attributes(@user)

      if @user.save
        @user.invite!(current_user)
        redirect_to staff_fosterers_path, notice: t(".success")
      else
        render "organizations/staff/fosterer_invitations/new", status: :unprocessable_entity
      end
    else
      authorize! User, context: {organization: Current.organization},
        with: Organizations::InvitationPolicy

      redirect_back fallback_location: root_path
    end
  end

  private

  def user_params
    params.require(:user)
      .permit(
        :first_name, :last_name, :email, :roles,
        person_attributes: [
          :phone_number,
          location_attributes: %i[country province_state city_town]
        ]
      )
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:accept_invitation, keys: %i[tos_agreement])
  end

  def after_accept_path_for(_resource)
    if allowed_to?(
      :index?, with: Organizations::DashboardPolicy,
      context: {organization: Current.organization}
    )
      staff_dashboard_index_path
    elsif allowed_to?(
      :index?, with: Organizations::AdopterFosterDashboardPolicy,
      context: {organization: Current.organization}
    )
      adopter_fosterer_dashboard_index_path
    else
      root_path
    end
  end

  # TODO: We should consider removing this duplicated logic, so we don't have to do this.
  def assign_person_attributes(user)
    person = user.person || user.build_person
    person.first_name = user.first_name
    person.last_name = user.last_name
    person.email = user.email
  end
end
