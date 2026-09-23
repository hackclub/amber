class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :start_request_timer
  before_action :require_login

  helper_method :current_user, :admin?

  private

  def start_request_timer
    Current.started_at = Time.current
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def admin?
    current_user&.admin? || false
  end

  def require_login
    return if current_user

    # Remembered so signing in lands you where you were headed — which the
    # OAuth consent screen depends on.
    session[:return_to] = request.fullpath if request.get? || request.head?
    redirect_to root_path, alert: "Please sign in to continue."
  end

  def require_admin!
    return if admin?

    redirect_to root_path, alert: "You don't have access to that."
  end
end
