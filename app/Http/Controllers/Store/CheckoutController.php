<?php

/**
 *    Copyright 2015-2017 ppy Pty. Ltd.
 *
 *    This file is part of osu!web. osu!web is distributed with the hope of
 *    attracting more community contributions to the core ecosystem of osu!.
 *
 *    osu!web is free software: you can redistribute it and/or modify
 *    it under the terms of the Affero GNU General Public License version 3
 *    as published by the Free Software Foundation.
 *
 *    osu!web is distributed WITHOUT ANY WARRANTY; without even the implied
 *    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *    See the GNU Affero General Public License for more details.
 *
 *    You should have received a copy of the GNU Affero General Public License
 *    along with osu!web.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace App\Http\Controllers\Store;

use App\Events\Fulfillment\PaymentCompleted;
use App\Libraries\CheckoutHelper;
use App\Libraries\Payments\OrderCheckoutCompleted;
use Auth;
use DB;
use Request;

class CheckoutController extends Controller
{
    protected $layout = 'master';


    public function __construct()
    {
        $this->middleware('auth', ['only' => [
            'store',
        ]]);

        $this->middleware('check-user-restricted', ['only' => [
            'store',
        ]]);

        $this->middleware('verify-user');

        return parent::__construct();
    }

    public function index()
    {
        $order = $this->userCart();
        if (!$order->items()->exists()) {
            return ujs_redirect('/store/cart');
        }

        // TODO: should be able to notify user that items were changed due to stock/price changes.
        $order->refreshCost();
        $checkout = new CheckoutHelper($order);
        $addresses = Auth::user()->storeAddresses()->with('country')->get();

        return view('store.checkout', compact('order', 'addresses', 'checkout'));
    }

    public function store()
    {
        $order = $this->userCart();

        if ($order->items()->count() === 0) {
            return error_popup('cart is empty');
        }

        if ((float) $order->getTotal() === 0.0 && Request::input('completed')) {
            DB::connection('mysql-store')->transaction(function () use ($order) {
                OrderCheckoutCompleted::run($order->getOrderNumber());
                $order->paid(null);
                event(new PaymentCompleted($order));
            });

            return ujs_redirect(route('store.invoice.show', ['invoice' => $order->order_id, 'thanks' => 1]));
        }

        return response()->json(['ok']);
    }
}
