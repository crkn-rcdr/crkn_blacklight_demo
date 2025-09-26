# README
A docker compose demo that will allow you to spin up a test instance of blacklight v8.8 (marc) in a flash.

# Ruby version
3.4.1

# System dependencies
Docker, Docker-compose

# Services 
Blacklight and Blacklight Marc depend on an apache solr Search Engine. For more information, see their [docs](https://github.com/crkn-rcdr/crkn_base_blacklight/blob/master/README.md#docs).
  
# Configuration

This repo is configured to pull and run solr through docker compose, and has the data folder mapped as a volume, which will allow the solr index to be created automatically for you, and will persist the information in the index for development or production needs.

For CRKN in production, we are using a solr instance running independantly from this docker compose. To configure the Solr instance to work with the Blacklight container, I sshed onto the Solr server, and performed the following:

`sudo cat /home/bitnami/bitnami_credentials`

Connect to the solr vm:

`ssh -i ~/.ssh/<id file>.pem <user>@4.229.225.26`

Created the blacklight_marc_demo core config directory:

`sudo mkdir /opt/bitnami/solr/server/solr/blacklight_marc_demo &&sudo mkdir /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf`

Copied the default configs to my new core:

`sudo cp -r /opt/bitnami/solr/server/solr/configsets/_default/conf/* /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf/`

Went into the new core's config directory:

`cd /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf/`

Removed the default solr config:

`sudo rm solrconfig.xml`

Pasted the solrconfig from this repo into a new solrconfig file:

`sudo vi solrconfig.xml`

Removed the default solr schema:

`sudo rm managed-schema.xml`

Pasted the solr schema from this repo into a new solr schema file:

`sudo vi managed-schema.xml`

Went to the solr server directory:

`cd /opt/bitnami/solr/server/solr`

Ensured the following users and permissions were configured:

`sudo vi security.json`
```
{
  "authorization": {
    "class":"solr.RuleBasedAuthorizationPlugin",
    "permissions":[
      {
        "name":"read",
        "role":[
          "admin",
          "public"
        ],
      },
      {
        "name":"all",
        "role":"admin",
      }
    ],
    "user-role":{
      "admin":"admin",
      "public":"public",
      "manager":"admin"
    }
  }
}
```

Restarted solr to apply the changes:

`sudo /opt/bitnami/ctlscript.sh restart solr`

# Developing Locally
Ensure docker and docker compose are installed. Then, enter the directory in your terminal, and run:

`docker compose up --build --force-recreate -d`

# Deployment Instructions
Run the following to push the image to docker hub:

`docker tag crkn_canadiana_blacklight-web brilap/crkn-demo`

`docker push brilap/crkn-demo`

Then restart the web app on [Azure](https://portal.azure.com/#@crkn.ca/resource/subscriptions/1bf1b056-be1d-4b1c-991f-2f154caf3061/resourceGroups/CRKN-demo-test/providers/Microsoft.Web/sites/canadiana-beta/appServices) to pull the new docker image.

# Docs
See Blacklight Wiki and Tutorials:
- https://github.com/projectblacklight/blacklight/wiki/
- https://workshop.projectblacklight.org/

To index a marc record from the terminal, you can enter the container on Docker Desktop (or through the docker exec command in your terminal) and run: 

`rake solr:marc:index MARC_FILE=marc-file-name-here.mrc`

A quick command to clear the solr index is:

`curl -X POST -H 'Content-Type: application/json' 'http://username:password@host/solr/blacklight_marc_demo/update?commit=true' -d '{ "delete": {"query":"*:*"} }'`
`curl -X POST -H 'Content-Type: application/json' 'http://localhost:8983/solr/blacklight_marc_demo/update?commit=true' -d '{ "delete": {"query":"*:*"} }'`

I ran these commands and saved the app directory as a mapped volume, so you shouldn't have to:

`rails generate --asset-delivery-mode=importmap-rails blacklight_range_limit:install`

`RAILS_ENV=production rails vite:build`





