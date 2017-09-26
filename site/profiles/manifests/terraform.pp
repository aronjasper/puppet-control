class profiles::terraform(
  $version = undef,
  ){

  exec { 'terraform':
    command     => "wget https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip -P /tmp/",
    user        => 'root',
    notify      => Exec['unzip'],
    refreshonly => true,
  }

  exec { 'unzip':
    command     => "unzip /tmp/terraform_${version}_linux_amd64.zip -d /bin/",
    user        => 'root',
    refreshonly => true,
  }

  file { '/bin/terraform' :
    ensure  => file,
    require => Exec['unzip'],
    owner   => root,
    group   => root,
    mode    => '0755'
  }
}
