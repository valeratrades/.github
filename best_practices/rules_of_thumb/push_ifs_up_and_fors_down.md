https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html

<body>
  <header>
    <nav>
      <a class="title" href="/">matklad</a>
      <a href="/about.html">About</a>
      <a href="/resume.html">Resume</a>
      <a href="/links.html">Links</a>
    </nav>
  </header>

  <main>
  <article >

<h1><span>Push Ifs Up And Fors Down</span> <time datetime="2023-11-15">Nov 15, 2023</time></h1>
<p><span>A short note on two related rules of thumb.</span></p>
<section id="Push-Ifs-Up">

    <h2>
    <a href="#Push-Ifs-Up"><span>Push Ifs Up</span> </a>
    </h2>
<p><span>If there</span>&rsquo;<span>s an </span><code>if</code><span> condition inside a function, consider if it could be moved to the caller instead:</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-comment">// GOOD</span></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">frobnicate</span>(walrus: Walrus) {</span>
<span class="line">    ...</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-comment">// BAD</span></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">frobnicate</span>(walrus: <span class="hl-type">Option</span>&lt;Walrus&gt;) {</span>
<span class="line">  <span class="hl-keyword">let</span> <span class="hl-variable">walrus</span> = <span class="hl-keyword">match</span> walrus {</span>
<span class="line">    <span class="hl-title function_ invoke__">Some</span>(it) =&gt; it,</span>
<span class="line">    <span class="hl-literal">None</span> =&gt; <span class="hl-keyword">return</span>,</span>
<span class="line">  };</span>
<span class="line">  ...</span>
<span class="line">}</span></code></pre>

</figure>
<p><span>As in the example above, this often comes up with preconditions: a function might check precondition</span>
<span>inside and </span>&ldquo;<span>do nothing</span>&rdquo;<span> if it doesn</span>&rsquo;<span>t hold, or it could push the task of precondition checking to</span>
<span>its caller, and enforce via types (or an assert) that the precondition holds. With preconditions</span>
<span>especially, </span>&ldquo;<span>pushing up</span>&rdquo;<span> can become viral, and result in fewer checks overall, which is one</span>
<span>motivation for this rule of thumb.</span></p>
<p><span>Another motivation is that control flow and </span><code>if</code><span>s are complicated, and are  a source of bugs. By</span>
<span>pushing </span><code>if</code><span>s up, you often end up centralizing control flow in a single function, which has a</span>
<span>complex branching logic, but all the actual work is delegated to straight line subroutines.</span></p>
<p><em><span>If</span></em><span> you have complex control flow, better to fit it on a screen in a single function, rather than</span>
<span>spread throughout the file. What</span>&rsquo;<span>s more, with all the flow in one place it often is possible to</span>
<span>notice redundancies and dead conditions. Compare:</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">f</span>() {</span>
<span class="line">  <span class="hl-keyword">if</span> foo &amp;&amp; bar {</span>
<span class="line">    <span class="hl-keyword">if</span> foo {</span>
<span class="line"></span>
<span class="line">    } <span class="hl-keyword">else</span> {</span>
<span class="line"></span>
<span class="line">    }</span>
<span class="line">  }</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">g</span>() {</span>
<span class="line">  <span class="hl-keyword">if</span> foo &amp;&amp; bar {</span>
<span class="line">    <span class="hl-title function_ invoke__">h</span>()</span>
<span class="line">  }</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">h</span>() {</span>
<span class="line">  <span class="hl-keyword">if</span> foo {</span>
<span class="line"></span>
<span class="line">  } <span class="hl-keyword">else</span> {</span>
<span class="line"></span>
<span class="line">  }</span>
<span class="line">}</span></code></pre>

</figure>
<p><span>For </span><code>f</code><span>, it</span>&rsquo;<span>s much easier to notice a dead branch than for a combination of </span><code>g</code><span> and </span><code>h</code><span>!</span></p>
<p><span>A related pattern here is what I call </span>&ldquo;<span>dissolving enum</span>&rdquo;<span> refactor. Sometimes, the code ends up</span>
<span>looking like this:</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-keyword">enum</span> <span class="hl-title class_">E</span> {</span>
<span class="line">  <span class="hl-title function_ invoke__">Foo</span>(<span class="hl-type">i32</span>),</span>
<span class="line">  <span class="hl-title function_ invoke__">Bar</span>(<span class="hl-type">String</span>),</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">main</span>() {</span>
<span class="line">  <span class="hl-keyword">let</span> <span class="hl-variable">e</span> = <span class="hl-title function_ invoke__">f</span>();</span>
<span class="line">  <span class="hl-title function_ invoke__">g</span>(e)</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">f</span>() <span class="hl-punctuation">-&gt;</span> E {</span>
<span class="line">  <span class="hl-keyword">if</span> condition {</span>
<span class="line">    E::<span class="hl-title function_ invoke__">Foo</span>(x)</span>
<span class="line">  } <span class="hl-keyword">else</span> {</span>
<span class="line">    E::<span class="hl-title function_ invoke__">Bar</span>(y)</span>
<span class="line">  }</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">g</span>(e: E) {</span>
<span class="line">  <span class="hl-keyword">match</span> e {</span>
<span class="line">    E::<span class="hl-title function_ invoke__">Foo</span>(x) =&gt; <span class="hl-title function_ invoke__">foo</span>(x),</span>
<span class="line">    E::<span class="hl-title function_ invoke__">Bar</span>(y) =&gt; <span class="hl-title function_ invoke__">bar</span>(y)</span>
<span class="line">  }</span>
<span class="line">}</span></code></pre>

</figure>
<p><span>There are two branching instructions here and, by pulling them up, it becomes apparent that it is</span>
<span>the exact same condition, triplicated (the third time reified as a data structure):</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-keyword">fn</span> <span class="hl-title function_">main</span>() {</span>
<span class="line">  <span class="hl-keyword">if</span> condition {</span>
<span class="line">    <span class="hl-title function_ invoke__">foo</span>(x)</span>
<span class="line">  } <span class="hl-keyword">else</span> {</span>
<span class="line">    <span class="hl-title function_ invoke__">bar</span>(y)</span>
<span class="line">  }</span>
<span class="line">}</span></code></pre>

</figure>
</section>
<section id="Push-Fors-Down">

    <h2>
    <a href="#Push-Fors-Down"><span>Push Fors Down</span> </a>
    </h2>
<p><span>This comes from data oriented school of thought. Few things are few, many things are many. Programs</span>
<span>usually operate with bunches of objects. Or at least the hot path usually involves handling many</span>
<span>entities. It is the volume of entities that makes the path hot in the first place. So it often is</span>
<span>prudent to introduce a concept of a </span>&ldquo;<span>batch</span>&rdquo;<span> of objects, and make operations on batches the base</span>
<span>case, with a scalar version being a special case of a batched ones:</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-comment">// GOOD</span></span>
<span class="line"><span class="hl-title function_ invoke__">frobnicate_batch</span>(walruses)</span>
<span class="line"></span>
<span class="line"><span class="hl-comment">// BAD</span></span>
<span class="line"><span class="hl-keyword">for</span> <span class="hl-variable">walrus</span> <span class="hl-keyword">in</span> walruses {</span>
<span class="line">  <span class="hl-title function_ invoke__">frobnicate</span>(walrus)</span>
<span class="line">}</span></code></pre>

</figure>
<p><span>The primary benefit here is performance. Plenty of performance, </span><a href="http://venge.net/graydon/talks/VectorizedInterpretersTalk-2023-05-12.pdf"><span>in extreme</span>
<span>cases</span></a><span>.</span></p>
<p><span>If you have a whole batch of things to work with, you can amortize startup cost and be flexible</span>
<span>about the order you process things. In fact, you don</span>&rsquo;<span>t even need to process entities in any</span>
<span>particular order, you can do vectorized/struct-of-array tricks to process one field of all entities</span>
<span>first, before continuing with other fields.</span></p>
<p><span>Perhaps the most fun example here is </span><a href="https://en.wikipedia.org/wiki/Sch%C3%B6nhage%E2%80%93Strassen_algorithm"><span>FFT-based polynomial</span>
<span>multiplication</span></a><span>: turns out,</span>
<span>evaluating a polynomial at a bunch of points simultaneously could be done faster than a bunch of</span>
<span>individual point evaluations!</span></p>
<p><span>The two pieces of advice about </span><code>for</code><span>s and </span><code>if</code><span>s even compose!</span></p>

<figure class="code-block">


<pre><code><span class="line"><span class="hl-comment">// GOOD</span></span>
<span class="line"><span class="hl-keyword">if</span> condition {</span>
<span class="line">  <span class="hl-keyword">for</span> <span class="hl-variable">walrus</span> <span class="hl-keyword">in</span> walruses {</span>
<span class="line">    walrus.<span class="hl-title function_ invoke__">frobnicate</span>()</span>
<span class="line">  }</span>
<span class="line">} <span class="hl-keyword">else</span> {</span>
<span class="line">  <span class="hl-keyword">for</span> <span class="hl-variable">walrus</span> <span class="hl-keyword">in</span> walruses {</span>
<span class="line">    walrus.<span class="hl-title function_ invoke__">transmogrify</span>()</span>
<span class="line">  }</span>
<span class="line">}</span>
<span class="line"></span>
<span class="line"><span class="hl-comment">// BAD</span></span>
<span class="line"><span class="hl-keyword">for</span> <span class="hl-variable">walrus</span> <span class="hl-keyword">in</span> walruses {</span>
<span class="line">  <span class="hl-keyword">if</span> condition {</span>
<span class="line">    walrus.<span class="hl-title function_ invoke__">frobnicate</span>()</span>
<span class="line">  } <span class="hl-keyword">else</span> {</span>
<span class="line">    walrus.<span class="hl-title function_ invoke__">transmogrify</span>()</span>
<span class="line">  }</span>
<span class="line">}</span></code></pre>

</figure>
<p><span>The </span><code>GOOD</code><span> version is good, because it avoids repeatedly re-evaluating </span><code>condition</code><span>, removes a branch</span>
<span>from the hot loop, and potentially unlocks vectorization. This pattern works on a micro level and on</span>
<span>a macro level </span>&mdash;<span> the good version is the architecture of TigerBeetle, where in the data plane we</span>
<span>operate on batches of objects at the same time, to amortize the cost of decision making in the</span>
<span>control plane.</span></p>
<p><span>While performance is perhaps the primary motivation for the </span><code>for</code><span> advice, sometimes it helps with</span>
<span>expressiveness as well. </span><code>jQuery</code><span> was quite successful back in the day, and it operates on</span>
<span>collections of elements. The language of abstract vector spaces is often a better tool for thought</span>
<span>than bunches of coordinate-wise equations.</span></p>
<p><span>To sum up, push the </span><code>if</code><span>s up and the </span><code>for</code><span>s down!</span></p>
</section>
</article>
  </main>

  <footer>
    <p>
      <a href="https://github.com/matklad/matklad.github.io/edit/master/content/posts/2023-11-15-push-ifs-up-and-fors-down.dj">
        <svg class="icon"><use href="/assets/icons.svg#edit"/></svg>
        Fix typo
      </a>
      <a href="/feed.xml">
        <svg class="icon"><use href="/assets/icons.svg#rss"/></svg>
        Subscribe
      </a>
      <a href="mailto:aleksey.kladov+blog@gmail.com">
        <svg class="icon"><use href="/assets/icons.svg#email"/></svg>
        Get in touch
      </a>
      <a href="https://github.com/matklad">
        <svg class="icon"><use href="/assets/icons.svg#github"/></svg>
        matklad
      </a>
    </p>
  </footer>
</body>
