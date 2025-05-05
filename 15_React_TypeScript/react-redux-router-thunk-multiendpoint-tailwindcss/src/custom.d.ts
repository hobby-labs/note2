// https://stackoverflow.com/a/45887328/4307818
declare module "*.svg" {
    // const content: React.FunctionComponent<React.SVGAttributes<SVGElement>>;
    const content: string;
    export default content;
}