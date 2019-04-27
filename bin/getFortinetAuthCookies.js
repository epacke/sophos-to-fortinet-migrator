const config = require('../config/config');
const request = require('request');
const fs = require('fs');

module.exports = function(){

    return new Promise(function(resolve, reject){

        var url = `${config.fortigate.adminURL}/logincheck`

        var cookieJar = request.jar();

        request.post({
            url : url,
            headers : {
                "Accept": "application/json"
            },
            agentOptions: {
                ca: fs.readFileSync('./caroot.crt'),   
            },
            jar: cookieJar,
            form: {
                username: config.fortigate.user,
                secretkey: config.fortigate.password
            }        
        },
        function (error, response, body) {
            console.log(cookieJar)
            resolve(cookieJar)
        })

    })
    
}
