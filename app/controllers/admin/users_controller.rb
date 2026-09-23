class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :update ]

  def index
    @users = User.order(:name)
  end

  def show
    @tickets = @user.tickets.order(created_at: :desc).includes(:service, :topic)
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "User updated."
    else
      redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.expect(user: [ :priority_boost ])
  end
end
