class_name ChatLog

var users = {}
var threads = {}
var indices = {}

var to_flush = {}

func append(user, thread_id, content, indices = []):
	if !(user in users):
		users[user] = []
		
	if !(thread_id in threads):
		threads[thread_id] = []
		users[user].push_back(thread_id)
	
	threads[thread_id].push_back(content)
	
	for i in indices:
		var value = content[i]
		if !(value in indices):
			indices[value] = []
		indices[value].push_back([user, thread_id, thread_id.size()-1])

	if !(user in to_flush):
		to_flush[user] = []
		
	to_flush[user].push_back([user, thread_id, content, indices])


func get_log(user, thread_id):

	if !(thread_id in threads):
		return null
		
	return threads[thread_id]
	
func find_value(val):
	if !(val in indices):
		return null
		
	return indices[val]
	
func flush():

	for u in to_flush:
		if to_flush[u].size() == 0:
			continue
		var fname = u+".log"
		var f = File.new()
		if f.file_exists(fname):
			f.open(fname, File.READ_WRITE)
		else:
			f.open(fname, File.WRITE)
		
		#printt("open file returned", u+".log", ret)
		f.seek(f.get_len())
		for v in to_flush[u]:
			f.store_var(v)
		f.close()
		to_flush.erase(u)
