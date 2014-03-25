# -*- encoding: utf-8 -*-
class Event < ActiveRecord::Base
  attr_accessible :library_id, :event_category_id, :name, :note, :start_at,
    :end_at, :all_day, :display_name, :required_role_id

#  scope :closing_days, includes(:event_category).where('event_categories.name = ?', 'closed') TODO original
  scope :closing_days, :include => :event_category, :conditions => ['event_categories.id = 2 OR event_categories.checkin_ng = ?', true] # TODO copy from enju_trunk
  scope :on, lambda {|datetime| where('start_at >= ? AND start_at < ?', datetime.beginning_of_day, datetime.tomorrow.beginning_of_day + 1)}
  scope :past, lambda {|datetime| where('end_at <= ?', Time.zone.parse(datetime).beginning_of_day)}
  scope :upcoming, lambda {|datetime| where('start_at >= ?', Time.zone.parse(datetime).beginning_of_day)}
  scope :at, lambda {|library| where(:library_id => library.id)}

  belongs_to :event_category, :validate => true
  belongs_to :library, :validate => true
  belongs_to :required_role, :class_name => 'Role', :foreign_key => 'required_role_id', :validate => true
  has_many :picture_files, :as => :picture_attachable
  has_many :participates, :dependent => :destroy
  has_many :agents, :through => :participates
  has_one :event_import_result  
  has_event_calendar
  has_paper_trail
  searchable do
    text :name, :note
    integer :library_id
    time :created_at
    time :updated_at
    time :start_at
    time :end_at
    integer :required_role_id
  end

  validates_presence_of :name, :library, :event_category, :required_role
  validates_associated :library, :event_category, :required_role
  validate :check_date
  before_validation :set_date
  before_validation :set_display_name, :on => :create

  paginates_per 10

  def set_date
    if self.start_at.blank?
      self.start_at = Time.zone.today.beginning_of_day
    end
    if self.end_at.blank?
      self.end_at = Time.zone.today.end_of_day
    end

    set_all_day
  end

  def set_all_day
    if all_day
      self.start_at = self.start_at.beginning_of_day
      self.end_at = self.end_at.end_of_day
    end
  end

  def check_date
    if self.start_at and self.end_at
      if self.start_at > self.end_at
        errors.add(:start_at)
        errors.add(:end_at)
      end
    end
  end

  def set_display_name
    self.display_name = self.name if self.display_name.blank?
  end

  def self.invalid(event, repeat)
    if repeat['end_date']
      begin
        end_date = Time.zone.parse(repeat['end_date'].to_s)
        start_date = Time.zone.parse(event['start_at'].to_s)
        if end_date.nil? || start_date.nil? || end_date < start_date
          false
        else
          true
        end
      rescue ArgumentError
        false
      end
    else
      true
    end
  end

  def self.set_recurring_event(event, repeat)
    event['display_name'] = event['name'] if event['display_name'].blank?
    recurring_events = Array.new()

    i = repeat['interval'].to_i
    rt = 365
    end_date = Time.now + 30.years

    start_day = Time.zone.parse(event['start_at'].to_s)
    weekday = {0 => :sunday, 1 => :monday, 2 => :tuesday, 3 => :wednesday, 4 => :thursday, 5 => :friday, 6 => :saturday}
    wd_name = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']

    start_at_time = Time.zone.parse(event['start_at'].to_s).seconds_since_midnight
    end_at_time = Time.zone.parse(event['end_at'].to_s).seconds_since_midnight

    if repeat['end_times']
      rt = repeat['end_times'].to_i
    elsif repeat['end_date']
      end_date = Time.zone.parse(repeat['end_date'].to_s)
    else
      end_date = Time.zone.parse(Term.get_term_end_at(event['start_at']).to_s)
    end

    if repeat['weekday']
      rt = rt + 1
      event['start_at'] = Time.zone.parse(event['start_at'].to_s) - i.weeks
      event['end_at'] = Time.zone.parse(event['end_at'].to_s) - i.weeks
    end

    rt.times do |r|

      start_at = Time.zone.parse(event['start_at'].to_s)
      end_at = Time.zone.parse(event['end_at'].to_s)

      case repeat['type']
      when "day" then
        event['start_at'] = (start_at + i.days)
        event['end_at'] = (end_at + i.days)
      when "week" then
        if repeat['weekday']
          start_at = start_at.prev_week
          end_at = end_at.prev_week
          wd_name.length.times do |w|
            if repeat['weekday'][wd_name[w]]
              event['start_at'] = (start_at + i.weeks).next_week(weekday[w]) + start_at_time
              event['end_at'] = (end_at + i.weeks).next_week(weekday[w]) + end_at_time
              if end_date >= Time.zone.parse(event['start_at'].to_s) && start_day < Time.zone.parse(event['start_at'].to_s)
                recurring_events << Event.new(event)
              end
            end
          end
        else
          event['start_at'] = (start_at + i.weeks)
          event['end_at'] = (end_at + i.weeks)
        end
      when "month" then
        if repeat['month_base_week']
          start_at += i.months
          end_at += i.months
          s = start_at.beginning_of_month + (repeat['month_base_week'].to_i - 1).weeks
          e = end_at.beginning_of_month + (repeat['month_base_week'].to_i - 1).weeks
          event['start_at'] = s.next_week(weekday[start_day.wday]) + start_at_time
          event['end_at'] = e.next_week(weekday[start_day.wday]) + end_at_time
        else
          event['start_at'] = (start_at + i.months)
          event['end_at'] = (end_at + i.months)
        end
      when "year" then
        event['start_at'] = (start_at + i.years)
        event['end_at'] = (end_at + i.years)
      else
        event['start_at'] = (start_at + i.days).to_s
        event['end_at'] = (end_at + i.days).to_s
      end

      if end_date < Time.zone.parse(event['start_at'].to_s)
        break
      elsif !repeat['weekday']
        recurring_events << Event.new(event)
      end
    end
    return recurring_events
  end
end
# == Schema Information
#
# Table name: events
#
#  id                :integer         not null, primary key
#  library_id        :integer         default(1), not null
#  event_category_id :integer         default(1), not null
#  name              :string(255)
#  note              :text
#  start_at          :datetime
#  end_at            :datetime
#  all_day           :boolean         default(FALSE), not null
#  deleted_at        :datetime
#  created_at        :datetime
#  updated_at        :datetime
#  display_name      :text
#

