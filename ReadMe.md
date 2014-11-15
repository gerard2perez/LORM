LORM
======
LOR is and Object Relational Model bulit to be used with corona SDK projetcs

>I've been working on it aboit of two months, and I've make a lot of changes since my first version about a month ago (today is 15/Nov/2014). So if something doesn't works as is written here please make me know.

##Features
* Multi-Context management
* Persistent Object
* JSON render
* Relationships
    * belongsTo
    * hasOne
    * hasMany
* Remote Database Sync
___

## Project Sample Estructure
* DataModel
 * All the files you need.
* LORM
 * lorm.lua
 * all the other files


*You must set then **LORMPath** variable to point the folder containing the LORM framework on the main.lua*
```lua
 LORMPath = 'DataModel'
```

## Setup your Dabatase
You basically need to define two things, your context and the tables that belongs to your context.
Since this ORM is though to be used alogn eith the Corona SDK the database used is SQLite3 and the database file will be stored en the documents folder of the user.
___
###Defining a DataBase context
In order to define a context we only need one file which call our defined models.
```lua
--file context.lua

local DEMO = {
    Namespace='Location_to_your_model',
    Database ='The_name_of_the_database',
    Grupo=[your_namespace].Grupo,
    Maestro=[your_namespace].Maestro
}
return require(LORMPath..".lorm"):new(DEMO)
```
>The last line is the constructor for your Context. After this the variable DEMO will contain the table definition which can also be access globally.
Keep in mind that is you have multiple context you shoul allways access your table trough your context variable. **aka DEMO ( for this example). **

___
### Defining a Table
When defining a table we can make use of the namespace variable (folder location) to define multiple tables for diferent contexts the default behaivor it let this tables accesible globally so be careful if you define multiple tables with the same name.
```lua
--File Model.lua
Model ={
    id = [[Column Attrinutes]],
    Column1 = [[Column Attrinutes]]
}
```
#### Column Attributes
> **DataType**: [ PRIMARY | INTEGER | TEXT | VIRTUAL | COLLECTION | DATETIME ]

> **Unic**: [ true | false]

> **FK**[array]: 
> 1. [belongsTo | hasOne | hasMany ]
> 2. Table from your Context
    
####Full Example
```lua
Maestro={
    MaestroId = {DataType=DataType.PRIMARY},
    Name = {UNIC=true},
    Password={DataType=DataType.TEXT},
    Grupo = {FK={FK.belongsTo,DataModel.Grupo}}
}
```
>> *If Primary key is not defined by default would be used **Id.** *

>> In this case * **DataModel** * is the name of the namespace.

----------


##**That's all the configuration you need to setup a Database **
___
##Your now ready to use LORM
___
#USAGE
*Requiere you context*.
```lua
require "context.lua"
```
Now all the clases you created would be accesible through the **_G** variable and would be instance of *EntityClass*.
##Sync Support Spicification
I'd build a simple REST sync suport for the database it bases on a UUSID variable which may allow to make unic the object even if we're syncing multiple devices.
###Requirements
1. **LORMConfig.TimeStamps** must be set to **true**
2. **LORMConfig.host** must point to the route base of your REST services server.
>You cant set this variable after you set the **LORMPath** variable.

###How it Works
Your model's name would be the resource that the ORM will ask for in your server. The request are done within the rest especification (more or less, i'm still working on it).

Let's supouse we have define the next model:
```lua
Alumno={
    Name={UNIC=true},
    Grupo={FK={FK.belongsTo,DataModel.Grupo}}
}
```
The class alumno will have attached to it the next methods:
1. Pull
2. Sync

And also every intance of the Alumno class will have a method called **sync**.

>These three methods will return a promise, since the request is async.
You can manage the result with the functions **done(HTTPresponse)** and **fail(HTTPresponse)**.

###EntityClass Pull()
This function makes a GET requeset. So, take a look of the next example:
```lua
Alumno:Pull():done(function(HTTP)
    print(HTTP.response)
end):fail(function(HTPP)
    print("Request has failed")
end)
```
>The url that this will try to gets is: **GET http://** *LORMConfig.host* **/alumno/ **
>And the response is expected to be a json array of alumnos.

###EntityClass Sync()
This function makes multiple PUT requests. So, take a look of the next example:
```lua
Alumno:Sync():done(function(HTTP)
    print('All objects in the table had been synced')
end):fail(function(HTPP)
    print("Request has failed")
end)
```
>This function makes a PUT request for every object in the table, so keep reading in order to kwon how the PUT request work. **This is important**

###Entity sync(override)
This function makes a PUT request. So, take a look of the next example:
```lua
local Alm = Alumno{Name='Juan'}
Alm:save()
Alm:sync():done(function(HTTP)
    print('Object has been synced')
end):fail(function(HTPP)
    print("Request has failed")
end)
```
This is the reason of why i say LORM is RESTful (more or less).

This example will make a request to:
>**PUT http://** *LORMConfig.host* **/alumno/_SSUID**
>Body:Name=Juan&Created=Date&Updated=Date&SSUID=_SSUID&Sync=

The posible responses LORM expect are:
1. 200:  Resource Updated or Overrided. Updates the Sync field.
2. 201: Resources Created. Updates the Sync filed.
3. 203: The object is older than the remote DB entry, and special action is executed if the **LORMConfig.RestSync.UpdateCriteria** is defined.
4. 207: No changes are required.
5. 409: Override permission is needed. This happens if the object we're posted was created after the entry in the remote DB. if the **LORMConfig.RestSync.AlwaysOverride** is set to *tru*e it'll make another request to override the remote DB entry.
6. Any other status code are threated as an error and you must deal with it though the **fail** callback.

>LORMConfig.RestSync.UpdateCriteria recives two arguments **Entity and HTTP**.

>**override** variable set creates and HTTP header ** *OVERRIDE* ** so you can read it in your server side implementation and take special actions.

If you have some questions about the server-side implementation of this methos take a look of the next code:
```php
/**
 * This codeis the one I used to test LORM it is written for a PhalconPHP MVC application.
**/
public function putAction($uusid){
        $_PUT = array();
        parse_str(file_get_contents('php://input'), $_PUT);
        //Get PUT parameters - phalcon issue.
        
        date_default_timezone_set('UTC');
        //I wannna work only with UTC TimeStamps.
        
        $Override = $this->request->getHeader('OVERRIDE');
        //Check if override flag is set.
        
        $Alumno = Alumno::findFirst("UUSID = '$uusid'");
        //Find the user UUSID.
        
        $_PUT['Id'] = null; //In case we are going to create a new user, I want the system to auto-assign an Id.
        $_PUT['Sync'] = (new DateTime())->format('Y-m-d H:i:s');
        
        $income_created = new DateTime($_PUT['Created']);
        $income_updated = new DateTime($_PUT['Updated']);
        //Make string a datetime so i can compare them.
        
        if( $Alumno->UUSID == null ){
        //This is a new Object
            $Alumno = new Alumno();
            $_PUT['UUSID'] = $uusid;
            $Alumno->save($_PUT);
            $this->response->setStatusCode(201, "Resource Created");
        }else{
        //There`s already this UUSID in the DB
            $stored_created = new DateTime($Alumno->Created);
            $stored_updated = new DateTime($Alumno->Updated);
            if($income_created > $stored_created){
            //The object was created after the object in database
                if($Override=="true"){
                //The object is explicit mark to be overriden
                    $this->response->setStatusCode(200, "Resource Overrided");
                    $Alumno->Name = $_PUT['Name'];
                    $Alumno->Created = $_PUT['Created'];
                    $Alumno->Updated = $_PUT['Updated'];
                    $Alumno->GruA_Id = $_PUT['GruA_Id'];
                    $Alumno->Sync   = $_PUT['Sync'];
                }else{
                //Tell the client there is a problem
                    $this->response->setStatusCode(409, "Override Permission Needed");   
                }
            }else if ($income_created < $stored_created){
            //The object where are posting is older than the DB object
                $this->response->setStatusCode(203, "Old Source");
            }else{
            //Creating Dates match!!
                if( $income_updated > $stored_updated ) {
                //Happy Path!! we just need to Updated de DB record with the incomming information.
                    $Alumno->Name = $_PUT['Name'];
                    $Alumno->Updated = $_PUT['Updated'];
                    $Alumno->GruA_Id = $_PUT['GruA_Id'];
                    $Alumno->Sync   = $_PUT['Sync'];
                    $this->response->setStatusCode(200, "Resource Updated");
                }else if($stored_updated > $income_updated ){
                //The source object was updated before the last DB objecy update. (Multi-Users).
                   $this->response->setStatusCode(203, "Old Source");
                }else{
                //Everything is up-to-date.
                    $this->response->setStatusCode(207, "Up-To-Date");
                }
            } 
        }
        
        $Alumno->save();
        //We save any change in the DB object.
        
        $this->response->setHeader("Content-Type", "application/json");
        $this->response->setContent( json_encode( $Alumno ) );    
        //And we always return and object.
        
        return $this->response;
    }
```

>This is only a suggestion if you want to make and application which only responds with 200 or 500, you're totally free to do it.

##Special considerations
Right now I have disabled auto-migration so you must delete the db file if yout want to change the databse(s) context(s), sorry :'(

Anyway I'm working on enable it again.

>I'm spanish speaker.
#Cheat Sheet
```lua
-- Creates a new object
local md1 = Model{ Colums='data', ... }
```
```lua
--Save The object
md1:save() --This method return's true or false
```
```lua
-- Delete the object
-- Delete it from the framework instance and
-- also form the database
md1:delete() --This method return's true or false
``` 
```lua
-- Undo all the changes to the last version of the object
md1:undo()
```
*The next functions returns the model object so you can chain the consult.*
```lua
--Aplies a where filter to find de object
Model:where('[[Column]]','[[Operant]]','[[value]]')
```
```lua
--Skips the first n results
Model:skip(n)
```
```lua
--Take 'n' results
Model:take(n)
```
```lua
--Return's the first result
Model:single()
```
```lua
--Return's and array of results
Model:get()
```
```lua
--Return's all the objects in the table as an array of results
Model:findAll()
```