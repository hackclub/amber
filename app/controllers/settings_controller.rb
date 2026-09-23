class SettingsController < ApplicationController
  def show
    # A freshly generated token is passed through the flash once — it can't be
    # recovered afterwards, since only its digest is stored.
    @new_token = flash[:api_token]
    @connections = current_user.oauth_tokens.active.includes(:oauth_client).order(created_at: :desc)
  end

  def api_token
    redirect_to settings_path, flash: { api_token: current_user.regenerate_api_token! }
  end

  def revoke_api_token
    current_user.revoke_api_token!
    redirect_to settings_path, notice: "API token revoked."
  end

  def revoke_connection
    connection = current_user.oauth_tokens.active.find(params[:id])
    connection.revoke!

    redirect_to settings_path, notice: "Disconnected #{connection.oauth_client.name}."
  end
end
