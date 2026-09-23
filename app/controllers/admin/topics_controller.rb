class Admin::TopicsController < Admin::BaseController
  before_action :set_topic, only: [ :edit, :update, :destroy ]

  def index
    @topics = Topic.includes(:service).order("services.name, topics.name").joins(:service)
  end

  def new
    @topic = Topic.new(service_id: params[:service_id])
    @services = Service.order(:name)
  end

  def create
    @topic = Topic.new(topic_params)

    if @topic.save
      redirect_to admin_topics_path, notice: "Topic created."
    else
      @services = Service.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @services = Service.order(:name)
  end

  def update
    if @topic.update(topic_params)
      redirect_to admin_topics_path, notice: "Topic updated."
    else
      @services = Service.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @topic.destroy
      redirect_to admin_topics_path, notice: "Topic deleted."
    else
      redirect_to admin_topics_path, alert: @topic.errors.full_messages.to_sentence
    end
  end

  private

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def topic_params
    params.expect(topic: [ :name, :active, :service_id ])
  end
end
