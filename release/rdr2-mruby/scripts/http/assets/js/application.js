
let ApplicationMap = class {
  constructor(container, svg, img_bg) {
    this.container = container;
    this.svg = svg;
    this.img_bg = img_bg;

    this.markers = {};
    this.model_hashes = {};

    this.a_x = 4577;
    this.a_y = 2182;
    this.a_w = 0.619;
    this.a_h = -0.69;
  }

  world2px( wx, wy ){
    let x = ((wx * this.a_w) + this.a_x);
    let y = ((wy * this.a_h) + this.a_y);
    return [x,y];
  }

  marker( data ) {
    let c = this.world2px( data.x , data.y );
    // console.log(x,y);
    // console.log(c[0],c[1]);
    let el = null;
    let tags = data.tags;
    tags = tags + ' model_'+data.model;
    tags = tags + ' model_'+(this.model_hashes[''+data.model]);
    if( el = $('#marker_'+data.id) ){

    }else{
      el = document.createElementNS("http://www.w3.org/2000/svg", "polygon");
      el.setAttribute( 'id', 'marker_'+data.id );
      el.setAttribute( 'points',  "-0.5,1 0,-1 0.5,1" );
      this.svg.appendChild(el);
      this.markers[data.id] = el;
    }
    el.setAttribute( 'class', tags );
    el.setAttribute( 'transform', [
      'translate(',c[0],',',c[1],') ',
      'rotate(',(360.0 - data.r),') ',
      'scale(2)'
    ].join('') );
  }

  update(data){
    let seen = {};
    data.forEach( (ent) => {
      window.app.map.marker( ent );
      seen[ ent.id ] = true;
    });
    Object.keys(this.markers).forEach( (id) => {
      if( !seen[id] ){
        this.svg.removeChild( this.markers[id] );
        delete this.markers[id];
      }
    } )
  }
};



$ = function(_){ return document.querySelector(_) };
$$ = function(_){ return document.querySelectorAll(_) };

window.app = {}
window.app.map = new ApplicationMap( $('#container') , $('#map_layers') , $('#map_background') );


async function coords_json(){
  response = await fetch('/coords.json');
  data = await response.json();
  window.app.map.update( data );
};

async function hashes_json(){
  response = await fetch('/hashes.json');
  data = await response.json();
  window.app.map.model_hashes = data;
};

hashes_json();

setInterval(coords_json,1000);
coords_json();
