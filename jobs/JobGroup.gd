tool
class_name JobGroup

var jobs: Array
var host
var callback: String
var output = []
var jobs_done
var id = -1
var runner

func job_done(job):
	var index = jobs.find(job)
	var job_count = jobs.size()
	if output.size() != job_count:
		output.resize(job_count)
	output[index] = job.output
	var done = 0
	for i in job_count:
		if jobs[i].state == Job.State.DONE:
			done += 1
	if done == job_count:
		if runner:
			runner.group_done(self)
	Job.callback_host(host, callback, self)
