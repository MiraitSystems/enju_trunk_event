# encoding: utf-8
namespace :enju_trunk_event do
  desc '土日祝日のEventを登録する(start[yyyymm],last[yyyymm],library_id)'
  task :generate_weekend_events, [:first_yyyy_mm, :last_yyyy_mm, :library_id] => :environment do |t, args|
    puts args

    unless args[:first_yyyy_mm] and args[:last_yyyy_mm] and args[:library_id]
      puts "usage: generate_weekend_events[201410,201412,1]"
      raise ArgumentError.new("first_yyyy_mm or last_yyyy_mm or library_id is empty.")
    end

    close_event_category = EventCategory.where(:name => 'closed').first
    holidays = {}
    day_names = I18n.t('date.day_names')
    require "csv"
    #
    # csv format : yyyymmdd,eventname
    # example: 
    # 20140505,子供の日
    # 20141123,勤労感謝の日
    #
    holiday_file = Rails.root.join('lib','tasks','generate_events_holidays.csv')
    puts "holiday_file=#{holiday_file}"

    if File.exist?(holiday_file)
      print "find csv file."
      CSV.open(holiday_file, "r") do |row|
        holidays[row[0]] = row[1]
        print "."
      end
      puts ""
    end

    puts "preload holiday #{holidays.size} event(s)."

    start_day = Date.new(args[:first_yyyy_mm][0..3].to_i, args[:first_yyyy_mm][-2..-1].to_i, 1)
    last_day = Date.new(args[:last_yyyy_mm][0..3].to_i, args[:last_yyyy_mm][-2..-1].to_i + 1, 1) - 1
    library_id = args[:library_id]

    puts "generate events. library_id=#{library_id} start=#{start_day} last=#{last_day}"

    (start_day..last_day).each do |day|
      if holidays[day.strftime('%Y%m%d')]
        event = Event.new
        event.library_id = args[:library_id]
        event.event_category = close_event_category
        event.name = "holiday"
        event.start_at = day.beginning_of_day
        event.end_at = day.end_of_day
        event.all_day = true
        event.display_name = holiday[day.strftime('%Y%m%d')]
        event.save!
      else
        if day.wday == 0 or day.wday == 6 then
          #TODO
          event = Event.find_or_initialize_by_start_at_and_end_at_and_all_day_and_library_id_and_name_and_event_category_id(
            start_at: day.beginning_of_day,
            end_at: day.end_of_day,
            all_day: true,
            library_id: library_id,
            event_category_id: close_event_category.id,
            name: "weekend"
          )
          event.display_name = day_names[day.wday] # "土曜日or日曜日"
          #puts "id=#{event.id} new?=#{event.new_record?}"
          event.save!
        end
      end
      print "."
    end

    puts ""
    puts "finish."
  end
end
