
package open_soc_debug

import Chisel._
import cde.{Parameters}

/** wormhole arbiter
  * @param T The type of wormhole flit
  * @param A The type of arbiter
  * @param gen Parameter to specify T
  * @param n Number of input ports
  * @param arb Arbiter generation function
  */
abstract class DebugWormholeArbiterLike[T <: DiiFlit](gen: T, n:Int)(arb: => LockingArbiterLike[T])(implicit p: Parameters)
    extends DebugNetworkModule()(p)
{
  val io = new ArbiterIO(gen, n)
  val arbiter = Module(arb)

  val chosen = Reg(init = Vec.fill(n)(Bool(false)))
  val transmitting = chosen.reduce(_||_)
  val out_valid = (0 until n) map ( i => { io.in(i).valid && chosen(i) }) reduce(_||_)

  io.in <> arbiter.io.in
  io.out <> arbiter.io.out

  io.out.valid := out_valid || (!transmitting && arbiter.io.out.valid)

  (0 until n).foreach( i => {
    when(io.in(i).fire()) {
      chosen(i) := !io.in(i).bits.last
    }
    arbiter.io.in(i).valid := chosen(i) || (!transmitting && io.in(i).valid)
    io.in(i).ready := arbiter.io.in(i).fire()
  })
}

/** Static priority arbiter
  */
class DebugWormholeArbiter[T <: DiiFlit](gen: T, n:Int)(implicit p: Parameters) extends
    DebugWormholeArbiterLike(gen,n)(new Arbiter(gen,n,true))(p)

/** Round-robin arbiter
  */
class DebugWormholeRRArbiter[T <: DiiFlit](gen: T, n:Int)(implicit p: Parameters) extends
    DebugWormholeArbiterLike(gen,n)(new RRArbiter(gen,n,true))(p)
