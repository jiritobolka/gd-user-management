# User Management App

## What It Does

This help helps you automate user provisioning and deprovisioning for given GoodData Project. This process might not be very easy especially if you have to operate hundreads of users.

You specify user list and action that is done by app using the KBC stored tables. The app will use the KBC GoodData Writer to invite / activate / deactivate user in specific project. 

See the example input below:

user, pid, action, writer_id, role, sso_provider
user@domain.com, x8rtiybsfuyxsrjqgw3quh4lrhco853a, DISABLE, writer_id, admin, sso-provider

All you need to do is to map table in the input mapping and specify **writer_id** that will be handling the requests.  

See the example output below:

user, job_id, status, action_done, timestamp
user@domain.com, 154626486, success, ENABLE, 2015-11-11 15:14:45 UTC

### So how to start?

1) Create list of user - actions
2) Setup the input mapping and writer id
3) Run the App
4) Check the result
