FROM tomcat:9.0

MAINTAINER eq
COPY demo/target/demo.war /usr/local/tomcat/webapps/
