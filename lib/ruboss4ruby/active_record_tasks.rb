require 'ruboss4ruby/tasks'

# these tasks are active record specific

APP_ENV = defined?(ENV['RAILS_ENV']) ? ENV['RAILS_ENV'] : ENV['MERB_ENV']

namespace :db do
  namespace :mysql do
    namespace :stage do
      desc "Stage production, test and development databases"
      task :all do
        db_names = %w(development test production)
        admin_password = ENV["ADMINPASS"] || ""
        db_user_name = ENV["USER"] || "root"
        db_password = ENV["PASS"] || ""
        stage_database(db_names, admin_password, db_user_name, db_password)
      end
    end

    desc "Stage the database environment for #{APP_ENV}"    
    task :stage do
      db_names = [APP_ENV]
      admin_password = ENV["ADMINPASS"] || ""
      db_user_name = ENV["USER"] || "root"
      db_password = ENV["PASS"] || ""
      stage_database(db_names, admin_password, db_user_name, db_password)
    end
  end  
    
  def stage_database(db_names, admin_password, db_user_name, db_password)
    sql_command = ""
    
    db_names.each do |name|
      db_name = ActiveRecord::Base.configurations[name]['database']
      sql_command += "drop database if exists #{db_name}; " << 
        "create database #{db_name}; grant all privileges on #{db_name}.* " << 
        "to #{db_user_name}@localhost identified by \'#{db_password}\';"
      ActiveRecord::Base.configurations[name]['username'] = db_user_name
      ActiveRecord::Base.configurations[name]['password'] = db_password
    end

    if (!File.exist?("#{APP_ROOT}/tmp/stage.sql"))
      File.open("#{APP_ROOT}/tmp/stage.sql", "w") do |file|
        file.print sql_command
      end
    end

    # back up the original database.yml file just in case
    File.copy("#{APP_ROOT}/config/database.yml", 
      "#{APP_ROOT}/config/database.yml.sample") if !File.exist?("#{APP_ROOT}/config/database.yml.sample")
    
    dbconfig = File.read("#{APP_ROOT}/config/database.yml")
    dbconfig.gsub!(/username:.*/, "username: #{db_user_name}")
    dbconfig.gsub!(/password:.*/, "password: #{db_password}")
    
    File.open("#{APP_ROOT}/config/database.yml", "w") do |file|
      file.print dbconfig
    end

    if system %(mysql -h localhost -u root --password=#{admin_password} < tmp/stage.sql)
      puts "Updated config/database.yml and staged the database based on your settings"
      File.delete("tmp/stage.sql") if File.file?("tmp/stage.sql")
    else
      puts "Staging was not performed. Check console for errors. It is possible that 'mysql' executable was not found."
    end
  end
  
  desc "Drop the database environment for #{APP_ENV} only if it exists"
  task :drop_if_exists do
    Rake::Task["db:drop"].invoke rescue nil
  end
    
  desc "Refresh the database environment for #{APP_ENV}"
  task :refresh => ['db:drop_if_exists', 'db:create', 'db:migrate', 'db:fixtures:load']
end