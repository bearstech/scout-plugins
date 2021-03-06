# =================================================================================
# This monitors detailed stats on specific celery task types (results/states, average runtime, etc)
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================

class CeleryTaskDetails < Scout::Plugin
  needs 'json'
  needs 'net/http'
  OPTIONS=<<-EOS    
  celerymon_url:        
    default: http://localhost:8989
    notes: The base URL of your Celerymon server.
  frequency:
    default: minute
    notes: The frequency at which sample rates should be calculated (ie "7 failures per minute").  Valid options are minute and second.
  task_name:
    notes: The fully qualified name of the task (ie module.tasks.my_task)
  EOS

  def build_report
    if option(:frequency) == "second"
        frequency = :second
    else
        frequency = :minute
    end

    task_name = option(:task_name).to_s.strip
    if task_name == ""
        error("You must choose a task to monitor", "Go to the plugin's settings page to enter a task name.")
        return
    end

    results = Hash.new {0}
    tasks = get_tasks_by_type(task_name).compact
    runtimes = []
    for task in tasks
        results[task[1]["state"]] += 1
        runtimes << task[1]['runtime']
    end
    runtimes = runtimes.compact
    if runtimes.size.zero?
        average_runtime = 0
    else
        average_runtime = runtimes.instance_eval { reduce(:+) / size.to_f }
    end
    report(:average_runtime => average_runtime)
    report(:total_recieved => results["RECEIVED"],
           :total_started => results["STARTED"],
           :total_successes => results["SUCCESS"],
           :total_retry => results["RETRY"],
           :total_failures => results["FAILURE"])
    counter(:failures, results["FAILURE"], :per => frequency)
    counter(:successes, results["SUCCESS"], :per => frequency)
    counter(:started, results["STARTED"], :per => frequency)
    counter(:recieved, results["RECEIVED"], :per => frequency)
    counter(:retry, results["RETRY"], :per => frequency)

  end

  def get_tasks
     url = "#{option('celerymon_url').to_s.strip}/api/task/?limit=0"
     result = query_api(url)
  end

  def get_tasks_for_worker(task_name)
     url = "#{option('celerymon_url').to_s.strip}/api/task/name/#{task_name}/"
     result = query_api(url)
  end

  def get_tasks_by_type(task_name)
     url = "#{option('celerymon_url').to_s.strip}/api/task/name/#{task_name}/"
     result = query_api(url)
  end


  def get_workers
     url = "#{option('celerymon_url').to_s.strip}/api/worker/"
     result = query_api(url)
  end

  def get_task_names
     url = "#{option('celerymon_url').to_s.strip}/api/task/name/"
     result = query_api(url)
  end

  def query_api(url)
     resp = Net::HTTP.get_response(URI.parse(url))
     data = resp.body

     # we convert the returned JSON data to native Ruby
     # data structure - a hash
     result = JSON.parse(data)

     # if the hash has 'Error' as a key, we raise an error
     #if result.has_key? 'Error'
     #   raise "web service error"
     #end
     return result
  end
end
