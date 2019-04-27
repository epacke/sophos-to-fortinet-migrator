const config = require('./config/config');
const request = require('request');
const fs = require('fs');
const getSophosHosts = require('./bin/getSophosHosts');
const getFortinetAuthCookies = require('./bin/getFortinetAuthCookies');
const express = require('express')

const app = express()
const port = 3000

async function main (){
    // Get the auth cookies required to work with the Fortinet device
    var cookieJar = await getFortinetAuthCookies();
}

app.get('/', (req, res) => res.send('Hello World!'))
app.listen(port, () => console.log(`Sophos to Fortinet migrator listening on port ${port}!`))
