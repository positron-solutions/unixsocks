use std::thread;
use std::io::{Read, Write};

use anyhow::{anyhow, Result};
use futures::join;
use smol::{net, prelude::*, channel::unbounded};
use structopt::StructOpt;

#[derive(StructOpt, Debug)]
#[structopt(name="unixsocks")]
struct Opt {
    #[structopt(short, long, parse(try_from_str))]
    socket_path: String,

    #[structopt(short, long, parse(try_from_str))]
    remote_host: String,

    #[structopt(short, long)]
    port: u16
}

fn main() -> Result<()> {

    let opt = Opt::from_args();
    let host = opt.remote_host.clone().into_bytes();

    smol::block_on(async {

        let mut sock_conn = net::unix::UnixStream::connect(&opt.socket_path).await?;
        let mut connect_req: Vec<u8> = Vec::new();
        connect_req.append(&mut vec![0x04, 0x01]);
        connect_req.append(&mut opt.port.clone().to_be_bytes().to_vec());
        connect_req.append(&mut vec![0x00, 0x00, 0x00, 0x01]);
        connect_req.push(0x00);
        connect_req.append(&mut host.clone());
        connect_req.push(0x00);

        sock_conn.write_all(&connect_req).await?;
        sock_conn.flush().await?;

        let mut resp_buffer: [u8; 8] = [0; 8];
        sock_conn.read_exact(&mut resp_buffer).await?;
        match resp_buffer[1] {
            0x5a => {
                // success
            },
            _ => {
                return Err(anyhow!(format!("Socks non-success response {:02X?}", &resp_buffer[1])))
            }
        }
        let (tx_sock, rx_sock) = unbounded::<Vec<u8>>();
        let (tx_std, rx_std) = unbounded::<Vec<u8>>();

        let stdout_thread = thread::spawn (move || {
            let mut stdout = std::io::stdout();
            smol::block_on(async {
            loop {
                match rx_std.recv().await  {
                    Ok(read) => {
                        match  stdout.write_all(&read) {
                            Ok(()) => {
                                match stdout.flush() {
                                    Ok(()) => (),
                                    Err(e) => {
                                        eprintln!("Could not flush stdout: {}", e);
                                        return
                                    }
                                }
                            },
                            Err(e) => {
                                eprintln!("Stdout could not be written: {}", e);
                                return
                            }
                        }
                    },
                    Err(_) => {
                        // channel closed
                        return
                    }
                }
            }
            });
        });

        let stdin_thread = thread::spawn (move || {
            let mut stdin = std::io::stdin();
            let mut buff = [0u8; 16_384];
            smol::block_on(async {
                loop {
                    match stdin.read(&mut buff) {
                        Ok(bytes_read) => {
                            match tx_sock.send(buff[0 .. bytes_read].to_vec()).await {
                                Ok(()) => {},
                                Err(_) => {
                                    // channel closed
                                    return
                                },
                            }
                        },
                        Err(e) => {
                            eprintln!("Stdin could not be read: {}", e);
                            return
                        }
                    }
                }
            });
        });

        let mut read_sock = sock_conn.clone();
        let mut write_sock = sock_conn.clone();

        let reading = async move {
            let mut buff = [0u8; 16_384];
            loop {
                match read_sock.read(&mut buff).await {
                    Ok(bytes_read) => {
                        match tx_std.send(buff[0 .. bytes_read].to_vec()).await {
                            Ok(()) => (),
                            Err(_) => {
                                // channel closed
                                break;
                            }
                        }
                    },
                    Err(e) => {
                        eprintln!("Could not read socket: {}", e);
                        break;
                    }
                };
            }
        };
        let writing = async move {
            loop {
                match rx_sock.recv().await {
                    Ok(msg) => {
                        match write_sock.write_all(&msg).await {
                            Ok(_) => {
                                match sock_conn.flush().await {
                                    Ok(_) => (),
                                    Err(e) => {
                                        eprintln!("Could not flush socket: {}", e);
                                        break;
                                    }
                                }
                            },
                            Err(e) => {
                                eprintln!("Could not write socket: {}", e);
                                break;
                            }
                        }
                    },
                    Err(_) => {
                        // channel closed
                        break;
                    }
                };
            }
        };

        join!(reading, writing);

        stdin_thread.join();
        stdout_thread.join();

        Ok(())
    })
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hello () {assert!(true)}
}
