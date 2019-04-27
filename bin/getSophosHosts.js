const config = require('../config/config');
const request = require('request');
const fs = require('fs');


module.exports = function(){

    return new Promise(resolve)
    const sophosAuth = "Basic " + new Buffer(config.sophos.user + ":" + config.sophos.password).toString("base64");
    const sophosUrl = `${config.sophos.adminURL}/api/objects/network/host/`

    request(
        {
            url : sophosUrl,
            headers : {
                "Authorization" : sophosAuth,
                "Accept": "application/json"
            },
            agentOptions: {
                ca: fs.readFileSync('./caroot.crt'),   
            }
        },
        function (error, response, body) {
            for(host of JSON.parse(body)){
            console.log(host)
            }
        }
    );

}