import requests
import json


def main():


    url = "http://localhost:80/admin/system/jsonrpc.php"
    headers = {'content-type': 'application/json'}

    # Example echo method
    payload = {
        # "method": "getdirs",
        # "method": "LBWeb::lbheader",
        "method": "get_lbfooter",
        # "method": "LBWeb::loglist_url",
        #"method": "LBWeb::logfile_button_html",
        # "method": "LBSystem::get_miniservers",
        # "params": [ { "PACKAGE": "squeezelite" } ],
		# "params": ["Top Plugin"],
        "params": [],
        "jsonrpc": "2.0",
        "id": 0,
    }

    print ("Calling method "+payload['method'])
    response = requests.post(
        url, data=json.dumps(payload), headers=headers)
    print ("Response RAW:\n"+response.text+"\n");
    respobj= response.json();

    #if respobj["result"]:
    #    print (respobj["result"])

if __name__ == "__main__":
    main()

