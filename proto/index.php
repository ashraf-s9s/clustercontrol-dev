<?php

$GLOBALS['servername'] = "127.0.0.1";
$GLOBALS['username'] = "cmon";
$GLOBALS['password'] = "cmon";
$GLOBALS['dbname'] = "cmon";

if ($_GET['send'] == "1") {
	$job_json='{
  "command": "create_container",
  "job_data": 
  {
    "docker_control": "' . $_GET['docker_control'] . '",
    "cluster_name": "' . $_GET['cluster_name'] . '",
    "cluster_type": "' . $_GET['cluster_type'] .'",
    "vendor": "' . $_GET['vendor'] . '",
    "provider_version": "' . $_GET['provider_version'] . '",
    "cluster_size": ' . $_GET['cluster_size'] . ',
    "db_root_password": "' . $_GET['db_root_password'] . '",
    "publish_port": ' . $_GET['publish_port'] . ',
    "network": "' . $_GET['networks'] . '"
  }
}';
	$conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
	// Check connection
	if (!$conn) {
	    die("Connection failed: " . mysqli_connect_error());
	}

	$sql = "INSERT INTO cmon.container_job (cid, jobspec, status, report_ts)
	VALUES (0, '$job_json', 'DEFINED', NOW())";

	if (mysqli_query($conn, $sql)) {
	    echo "The following job submitted:\n" . $job_json;
	} else {
	    echo "Error: " . $sql . "<br>" . mysqli_error($conn);
	}

mysqli_close($conn);
}
if ($_GET['scale'] == "1") {
        $job_json='{
  "command": "scale_container",
  "job_data":
  {
    "cluster_name": "' . $_GET['cluster_name'] . '",
    "cluster_size": ' . $_GET['cluster_size'] . ',
    "docker_control": "' . $_GET['docker_control'] . '"
  }
}';
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        // Check connection
        if (!$conn) {
            die("Connection failed: " . mysqli_connect_error());
        }

        $sql = "INSERT INTO cmon.container_job (cid, jobspec, status, report_ts)
        VALUES (0, '$job_json', 'DEFINED', NOW())";

        if (mysqli_query($conn, $sql)) {
            echo "The following job submitted:\n" . $job_json;
        } else {
            echo "Error: " . $sql . "<br>" . mysqli_error($conn);
        }

mysqli_close($conn);
}

?>
<html>
<br>
<button onclick="window.location='index.php';">Refresh</button>
<hr>
<table width='100%'>
<tr><td>
<form action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]);?>" method="get" id="form1">
<h2>Create Cluster</h2>
<h3> Cluster Details </h3>
  Cluster type:  <select name="cluster_type">
	<option value="galera">Galera Cluster</option>
	<option value="replication">MySQL Replication</option>
</select><br>
  Vendor: <select name="vendor">
	<option value="percona">Percona</option>
	<option value="codership">Codership</option>
	<option value="mariadb">MariaDB</option>
</select><br>
  Provider version: <select name="provider_version">
	<option value="5.7">5.7</option>
	<option value="5.6">5.6</option>
	<option value="10.1">10.1</option>
	<option value="10.0">10.0</option>
</select><br>
  Cluster name:  <input type="text" name="cluster_name">**unique, no space**<br>
  DB Root Password: <input type="text" name="db_root_password"><br>

<h3> Containers </h3>
  DockerControl: <select name="docker_control">
<?php
	$sql = "SELECT host_ip,hostname FROM cmon.dockercontrol";
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        $result = $conn->query($sql);

if ($result->num_rows > 0) {
    // output data of each row
    while($row = $result->fetch_assoc()) {
        echo "<option value=" . $row["host_ip"]. ">" . $row["hostname"]. "</option>";
    }
} else {
    echo "0 results";
}

?>

</select><br>
  No of Containers: <input type="text" name="cluster_size"> (Cluster size)<br>
  Publish Port: <input type="text" name="publish_port"><br>
  Network: <select name="networks">
<?php
        $sql = "SELECT networks FROM cmon.dockercontrol LIMIT 1";
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        $result = $conn->query($sql);

if ($result->num_rows > 0) {
    // output data of each row
    while($row = $result->fetch_assoc()) {
	$data = $row["networks"];
	$data2 = (explode(';', $data));
	foreach ($data2 as $i){
		$j=str_replace('"','',$i);
		echo '<option value="'. $j . '">'. $j .'</option>';
	}
    }
} else {
    echo "0 results";
}

?>
</select>
<input type="hidden" name="send" value="1">
</form>
<button type="submit" form="form1" value="Submit">Deploy!</button>
<hr>
<h2>Cluster List</h2>
<?php
        $sql = "SELECT cluster_name, cluster_type, vendor, provider_version, db_root_password, count(distinct(ip)) as containers FROM cmon.containers GROUP BY cluster_name HAVING AVG(deployed) = 1 AND AVG(created) = 1";
	$sql2 = "SELECT ";
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        $result = $conn->query($sql);

if ($result->num_rows > 0) {
    echo '<table border=1>';
    echo '<tr><th>Cluster Name</th><th>Cluster Type</th><th>Vendor</th><th>Provider Version</th><th>Service Name</th><th>containers</th></tr>';
    while($row = $result->fetch_assoc()) {
        echo '<tr><td>' . $row["cluster_name"] . '</td><td>' . $row["cluster_type"] . '</td><td>' . $row["vendor"] . '</td><td>'.$row["provider_version"] . '</td><td> cc_' . $row["cluster_name"] . '</td><td>' . $row["containers"] . '</td></tr>';
    }
    echo '</table>';
} else {
    echo "0 results";
}

?>
<hr>
<h2>Scale Cluster</h2>
<form action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]);?>" method="get" id="form2">
  Cluster Name: <select name="cluster_name">
<?php
	$sql = "SELECT cluster_name FROM cmon.containers GROUP BY cluster_name HAVING AVG(deployed) = 1 AND AVG(created) = 1";
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        $result = $conn->query($sql);

if ($result->num_rows > 0) {
    // output data of each row
    while($row = $result->fetch_assoc()) {
        echo "<option value=" . $row["cluster_name"]. ">" . $row["cluster_name"]. "</option>";
    }
} else {
    echo "0 results";
}

?>
</select><br>
No of Containers: <input type="text" name="cluster_size"> (Cluster size)<br>
  DockerControl: <select name="docker_control">
<?php
        $sql = "SELECT host_ip,hostname FROM cmon.dockercontrol";
        $conn = new mysqli($GLOBALS['servername'],$GLOBALS['username'],$GLOBALS['password'],$GLOBALS['dbname']);
        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }
        $result = $conn->query($sql);

if ($result->num_rows > 0) {
    // output data of each row
    while($row = $result->fetch_assoc()) {
        echo "<option value=" . $row["host_ip"]. ">" . $row["hostname"]. "</option>";
    }
} else {
    echo "0 results";
}

?>

<input type="hidden" name="scale" value="1">
</form>
<button type="submit" form="form2" value="Submit">Scale!</button>
</td><td>
<h2> Logs </h2>
<iframe src="deploy.txt" scrolling="yes" width='100%' height='600px'></iframe>
</td></tr>
</table>
</html>
