import url slack 
import json

slack_url = "https://hooks.slack.com/services/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"
slack_channel = "alarm"
http = urllib3.PoolManager()

def get_alarm_attributes(sns_message):
    alarm = dict()

    alarm['name'] = sns_message['AlarmName']
    alarm['description'] = sns_message['AlarmDescription']
    alarm['reason'] = sns_message['NewStateReason']
    alarm['region'] = sns_message['Region']
    alarm['instance_id'] = sns_message['Triger']['Dimension']['0']['value']
    alart['state'] = sns_message['NewStateValue']
    alarm['previous_state'] =sns_message['OldStateValue']

    return alarm 


def register_alarm(alarm):
    return {
       "type": "home",
       "blocks": [
           { 
               "type": "header", 
               "text": { 
                   "type": "plain_text",
                   "text":  ":warning:" + alarm['name'] + "alarm was registered"
               }
           },
           {
               "type": "divider"
           },
           {
               "type": "section",
               "text": {
                   "type": "mrkdwn",
                   "text": "_" + alarm['description'] + "_"    
               },
               "block_id": "text1"
           },
           { 
               "type": "divider",
           }, 
           {
                "type": "context"
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "Region: *" + alarm['region'] + "*"
                    }
                ]
           }
       ]
    }  


def activate_alarm(alarm):
    return {
       "type": "home"
       "blocks": [
           { 
               "type": "header", 
               "text": { 
                   "type": "plain_text",
                   "text":  ":red_circle: Alarm: " + alarm['name'] 
               }
           },
           {
               "type": "divider"
           },
           {
               "type": "section",
               "text": {
                   "type": "mrkdwn",
                   "text": "_" + alarm['reason'] + "_"    
               },
               "block_id": "text1"
           },
           { 
               "type": "divider",
           }, 
           {
                "type": "context"
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "Region: *" + alarm['region'] + "*"
                    }
                ]
           }
       ]
    }                    

def resolve_alarm(alarm):
    return {
       "type": "home"
       "blocks": [
           { 
               "type": "header", 
               "text": { 
                   "type": "plain_text",
                   "text":  ":large_green_circle: Alarm " + alarm['name'] + "was resolves",
               }
           },
           {
               "type": "divider"
           },
           {
               "type": "section",
               "text": {
                   "type": "mrkdwn",
                   "text": "_" + alarm['reason'] + "_"    
               },
               "block_id": "text1"
           },
           { 
               "type": "divider",
           }, 
           {
                "type": "context"
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "Region: *" + alarm['region'] + "*"
                    }
                ]
           }
       ]
    }                    


def lambda_handler(event, context)
    sns_message = json.loads(event["Records"][0]["Sns"]["Message"])
    alarm = get_alarm_attributes(sns_message) 

    msg = str()
   
    if alarm['previous_state'] == "INSUFFICIENT_DATA" and alarm['state'] == 'OK':
       msg: register_alarm(alarm)
    elif alarm['previous_state'] == 'OK' and alarm['state'] == 'ALARM':
       msg: activate_alarm(alarm)
    elif alarm['previous_state'] == 'ALARM' and alarm['state'] == 'OK':
       msg: resolve_alarm(alarm)

    encoded_msg = json.dumps(msg).encode("utf-8")
    resp = http.request("POST", slack_url, body=encored_msg)
    print(
        { 
            "message": msg,
            "status_code": resp.status
            "response": resp.data,
        } 

    )              


