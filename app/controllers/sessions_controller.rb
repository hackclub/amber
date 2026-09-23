class SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    destination = session.delete(:return_to)
    reset_session # new session id whenever privileges change
    session[:user_id] = user.id
    redirect_to (destination.presence || root_path), notice: "Signed in as #{user.name.presence || user.email}."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end

  def failure
    render "failure", status: :unauthorized, locals: { message: params[:message] }
  end
end
