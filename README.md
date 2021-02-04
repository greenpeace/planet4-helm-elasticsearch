[![Greenpeace](https://circleci.com/gh/greenpeace/planet4-helm-elasticsearch.svg?style=shield)](https://circleci.com/gh/greenpeace/planet4-helm-elasticsearch)

![Planet4](./p4logo.png)
# Elasticsearch

Elasticsearch is the distributed search and analytics engine at the heart of the Elastic Stack.  Used by the Wordpress plugin Elasticpress to index posts.

<h1>Important Notes</h1>

>Ensure compatibility with:
- Elasticpress plugin in WP
- [Docker Image for plugins](https://github.com/greenpeace/planet4-docker-elasticsearch)
- [ES-exporter](https://github.com/greenpeace/planet4-helm-esexporter)
- [Kibana]()
- APM()

***
### Requirements - Internal Only
-   Access to P4 Infra [environment](https://www.notion.so/p4infra/bab9d0b1f2db4d929a59916899d531c1?v=eca7b78e1ae345c6883a9b37c6b76cac)

### Built with
- [elasticsearch](https://github.com/elastic/helm-charts/tree/master/elasticsearch) helm chart

### Deployment
This repository is deployed via [CircleCI](https://circleci.com/gh/greenpeace/planet4-traefik)

 - Commits to the develop branch trigger deployment to the development cluster.  
 - Create a PR for review to prepare for production deployment.
 - Approval and merge deploys to production.

### Usage
 - To access Elasticsearch from within your cluster, use:
    `$RELEASE-elasticsearch-client.$NAMESPACE.svc.cluster.local:9200`
 - Clone the repo to access makefile commands via cli that are not executed via CircleCI
   - `make status` - <em> display status of named release </em>
   - `make value` - <em> display user values followed by all values deployed </em>
   - `make port` - <em> expose the 9200 port to access via your local machine </em>
   - `make history` - <em> display deployment history of named release </em>
   - `make uninstall` - <em> delete release while retaining history, CRDs, PVs etc.</em>
   - `make destroy` - <em> destroy release including CRDs, PVs etc. </em> <strong> CAUSES DATA LOSS </strong>

 ### Infra Documentation
 - External
   - [Planet 4 Handbook](https://app.gitbook.com/@greenpeace/s/planet4/infrastructure/intro)
 - Internal use only
   - [P4 Notion](https://www.notion.so/p4infra/)

 ### Contributing
 If your interested in contributing to P4 Infrastructure code please check our our community page [here](https://github.com/greenpeace/planet4).
