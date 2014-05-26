# -*- encoding: utf-8 -*-
class EventsController < ApplicationController
  add_breadcrumb "I18n.t('page.listing', :model => I18n.t('activerecord.models.event'))", 'messages_path', :only => [:index]
  add_breadcrumb "I18n.t('page.showing', :model => I18n.t('activerecord.models.event'))", 'event_path(params[:id])', :only => [:show]
  add_breadcrumb "I18n.t('page.new', :model => I18n.t('activerecord.models.event'))", 'new_event_path', :only => [:new, :create]
  add_breadcrumb "I18n.t('page.editing', :model => I18n.t('activerecord.models.event'))", 'edit_event_path(params[:id])', :only => [:edit, :update]
  load_and_authorize_resource
  before_filter :get_library, :get_agent
  before_filter :get_libraries, :except => :destroy
  before_filter :prepare_options
  before_filter :store_page, :only => :index
  after_filter :solr_commit, :only => [:create, :update, :destroy]
  after_filter :convert_charset, :only => :index

  # GET /events
  # GET /events.json
  def index
    @count = {}
    query = params[:query].to_s.strip
    @query = query.dup
    query = query.gsub('　', ' ')
    tag = params[:tag].to_s if params[:tag].present?
    date = params[:date].to_s if params[:date].present?
    mode = params[:mode]

    search = Sunspot.new_search(Event)
    library = @library
    role_id = current_user.role.id rescue nil || Role.where(:name => 'Guest').first.id
    search.build do
      fulltext query if query.present?
      with(:required_role_id).less_than_or_equal_to role_id
      with(:library_id).equal_to library.id if library
      if date
        with(:start_at).less_than_or_equal_to Time.zone.parse(date)
        with(:end_at).greater_than Time.zone.parse(date)
      end
      case mode
      when 'upcoming'
        with(:start_at).greater_than Time.zone.now.beginning_of_day
      when 'past'
        with(:start_at).less_than Time.zone.now.beginning_of_day
      end
      order_by(:start_at, :desc)
    end

    page = params[:page] || 1
    search.query.paginate(page.to_i, Event.default_per_page)
    @events = search.execute!.results
    @count[:query_result] = @events.total_entries

    respond_to do |format|
      format.html { render :template => 'opac/events/index', :layout => 'opac' } if params[:opac]
      format.html # index.html.erb
      format.json { render :json => @events }
      format.rss  { render :layout => false }
      format.csv
      format.atom
      format.ics
    end
 end

  # GET /events/1
  # GET /events/1.json
  def show
    @event = Event.find(params[:id])

    unless @event.required_role.name == 'Guest' && !current_user.try(:has_role, @event.required_role.name)
       access_denied; return
    end
    respond_to do |format|
      format.html { render :template => 'opac/events/show', :layout => 'opac' } if params[:opac]
      format.html # show.html.erb
      format.json { render :json => @event }
    end
  end

  # GET /events/new
  # GET /events/new.json
  def new
     prepare_options
    @date = get_date
    @event = Event.new(:start_at => @date, :end_at => @date)
    @event.library = @library

    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @event }
    end
  end

  # GET /events/1/edit
  def edit
    @event = Event.find(params[:id])
    prepare_options
  end

  # POST /events
  # POST /events.json
  def create
    @date = get_date
    repeat_invarid = true
    repeat_invarid = Event.invalid(params[:event] , params[:repeat]) if params[:repeat]

    @event = Event.new(params[:event])
    @event.set_date

    respond_to do |format|
      if @event.valid? && repeat_invarid
        @event.save
        if params[:repeat].present?
          repeat_event = params[:event]
          repeat_event['start_at'] = @event.start_at
          repeat_event['end_at'] = @event.end_at
          Event.import Event.set_recurring_event(repeat_event, params[:repeat])
        end
        flash[:notice] = t('controller.successfully_created', :model => t('activerecord.models.event'))
        format.html { redirect_to :controller => 'calendar', :action => 'index' }
       # format.html { redirect_to(@event) }
        format.json { render :json => @event, :status => :created, :location => @event }
      else
        prepare_options
        if !repeat_invarid && @event.valid?
          flash[:notice] = t('repeat.error')
          format.html { redirect_to :controller => 'calendar', :action => 'index' }
        end
        format.html { render :action => "new" }
        format.json { render :json => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /events/1
  # PUT /events/1.json
  def update
    @event = Event.find(params[:id])
    @event.set_date

    respond_to do |format|
      if @event.update_attributes(params[:event])
        flash[:notice] = t('controller.successfully_updated', :model => t('activerecord.models.event'))
        format.html { redirect_to(@event) }
        format.json { head :no_content }
      else
        prepare_options
        format.html { render :action => "edit" }
        format.json { render :json => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.json
  def destroy
    @event = Event.find(params[:id])
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_url }
      format.json { head :no_content }
    end
  end

  private
  def prepare_options
    @event_categories = EventCategory.all
    @roles = Role.all
  end

  private
  def get_date
    if params[:date]
      begin
        d = Time.zone.parse(params[:date])
      rescue ArgumentError
        d = Time.zone.now.beginning_of_day
        flash[:notice] = t('page.invalid_date')
      end
    else
      d = Time.zone.now.beginning_of_day
    end
    d
  end
end
