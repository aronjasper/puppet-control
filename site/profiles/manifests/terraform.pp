class profiles::terraform(
  $version = undef,
  ){

  exec { 'terraform':
    command => "wget https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip -P /tmp/",
    user    => 'root',
    notify  => Exec['unzip'],
    unless  => "ls /tmp/terraform_${version}_linux_amd64.zip"
  }

  exec { 'unzip':
    command => "unzip -o /tmp/terraform_${version}_linux_amd64.zip -d /bin/",
    user    => 'root',
    unless  => 'ls /bin/terraform'
  }

  file { '/bin/terraform' :
    require => Exec['unzip'],
    owner   => root,
    group   => root,
    mode    => '0755'
  }
}
